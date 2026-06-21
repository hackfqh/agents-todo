import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

enum AgentKind { codex, claudeCode, openClaw }

extension AgentKindDetails on AgentKind {
  String get id {
    return switch (this) {
      AgentKind.codex => 'codex',
      AgentKind.claudeCode => 'claude_code',
      AgentKind.openClaw => 'openclaw',
    };
  }

  String get label {
    return switch (this) {
      AgentKind.codex => 'Codex',
      AgentKind.claudeCode => 'Claude Code',
      AgentKind.openClaw => 'OpenClaw',
    };
  }

  static AgentKind? fromId(String id) {
    for (final kind in AgentKind.values) {
      if (kind.id == id) {
        return kind;
      }
    }
    return null;
  }
}

class AgentConversation {
  const AgentConversation({
    required this.agent,
    required this.sessionId,
    required this.updatedAt,
    required this.runs,
  });

  final AgentKind agent;
  final String sessionId;
  final DateTime updatedAt;
  final List<AgentRun> runs;

  Map<String, dynamic> toJson() {
    return {
      'agent': agent.id,
      'sessionId': sessionId,
      'updatedAt': updatedAt.toIso8601String(),
      'runs': runs.map((run) => run.toJson()).toList(),
    };
  }

  factory AgentConversation.fromJson(
    AgentKind agent,
    Map<String, dynamic> json,
  ) {
    final rawRuns = json['runs'];
    return AgentConversation(
      agent: agent,
      sessionId: json['sessionId'] as String? ?? '',
      updatedAt: _readDateTime(json['updatedAt']) ?? DateTime.now(),
      runs: rawRuns is List
          ? rawRuns
                .whereType<Map>()
                .map(
                  (item) => AgentRun.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }
}

class AgentRun {
  const AgentRun({
    required this.id,
    required this.agentId,
    required this.instruction,
    required this.output,
    required this.error,
    required this.exitCode,
    required this.startedAt,
    required this.finishedAt,
  });

  final String id;
  final String agentId;
  final String instruction;
  final String output;
  final String? error;
  final int exitCode;
  final DateTime startedAt;
  final DateTime finishedAt;

  bool get succeeded => exitCode == 0 && error == null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'agentId': agentId,
      'instruction': instruction,
      'output': output,
      'error': error,
      'exitCode': exitCode,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt.toIso8601String(),
    };
  }

  factory AgentRun.fromJson(Map<String, dynamic> json) {
    return AgentRun(
      id: json['id'] as String? ?? '',
      agentId: json['agentId'] as String? ?? '',
      instruction: json['instruction'] as String? ?? '',
      output: json['output'] as String? ?? '',
      error: json['error'] as String?,
      exitCode: json['exitCode'] as int? ?? 0,
      startedAt: _readDateTime(json['startedAt']) ?? DateTime.now(),
      finishedAt: _readDateTime(json['finishedAt']) ?? DateTime.now(),
    );
  }
}

class AgentTaskRequest {
  const AgentTaskRequest({
    required this.agent,
    required this.title,
    required this.details,
    required this.instruction,
    required this.conversation,
    required this.workingDirectory,
    required this.projectName,
    required this.projectPath,
  });

  final AgentKind agent;
  final String title;
  final String details;
  final String instruction;
  final AgentConversation? conversation;
  final String workingDirectory;
  final String projectName;
  final String projectPath;
}

class AgentTaskResult {
  const AgentTaskResult({
    required this.sessionId,
    required this.output,
    required this.error,
    required this.exitCode,
    required this.rawOutput,
  });

  final String? sessionId;
  final String output;
  final String? error;
  final int exitCode;
  final String rawOutput;
}

abstract class AgentTaskRunner {
  Future<AgentTaskResult> run(AgentTaskRequest request);
}

class CliAgentTaskRunner implements AgentTaskRunner {
  const CliAgentTaskRunner({this.timeout = const Duration(minutes: 20)});

  final Duration timeout;

  @override
  Future<AgentTaskResult> run(AgentTaskRequest request) {
    final prompt = buildAgentPrompt(request);
    return switch (request.agent) {
      AgentKind.codex => _runCodex(request, prompt),
      AgentKind.claudeCode => _runClaudeCode(request, prompt),
      AgentKind.openClaw => _runOpenClaw(request, prompt),
    };
  }

  Future<AgentTaskResult> _runCodex(
    AgentTaskRequest request,
    String prompt,
  ) async {
    final outputFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'todo_desk_codex_${DateTime.now().microsecondsSinceEpoch}.txt',
    );
    final existingSessionId = _usableSessionId(request.conversation);
    final args = existingSessionId == null
        ? [
            'exec',
            '--skip-git-repo-check',
            '--sandbox',
            'workspace-write',
            '--color',
            'never',
            '--json',
            '--output-last-message',
            outputFile.path,
            '-',
          ]
        : [
            'exec',
            'resume',
            '--skip-git-repo-check',
            '--json',
            '--output-last-message',
            outputFile.path,
            existingSessionId,
            '-',
          ];

    final processResult = await _runShellCommand(
      executable: 'codex',
      args: args,
      stdinText: prompt,
      workingDirectory: request.workingDirectory,
    );
    final outputFromFile = await _readOutputFile(outputFile);
    final rawOutput = '${processResult.stdout}\n${processResult.stderr}'.trim();
    final output = outputFromFile.isNotEmpty
        ? outputFromFile
        : _extractOutput(processResult.stdout).trim();
    final parsedSessionId = _extractSessionId(rawOutput) ?? existingSessionId;

    return AgentTaskResult(
      sessionId: parsedSessionId,
      output: output.isEmpty ? rawOutput : output,
      error: processResult.exitCode == 0 ? null : _readError(processResult),
      exitCode: processResult.exitCode,
      rawOutput: rawOutput,
    );
  }

  Future<AgentTaskResult> _runClaudeCode(
    AgentTaskRequest request,
    String prompt,
  ) async {
    final existingSessionId = _usableSessionId(request.conversation);
    final sessionId = existingSessionId ?? _generateUuid();
    final args = [
      '--print',
      '--output-format',
      'json',
      '--permission-mode',
      'acceptEdits',
      if (existingSessionId == null) ...['--session-id', sessionId],
      if (existingSessionId != null) ...['--resume', existingSessionId],
      prompt,
    ];

    final processResult = await _runShellCommand(
      executable: 'claude',
      args: args,
      workingDirectory: request.workingDirectory,
    );
    final rawOutput = '${processResult.stdout}\n${processResult.stderr}'.trim();
    final parsedSessionId =
        _extractSessionId(rawOutput) ?? existingSessionId ?? sessionId;
    final output = _extractOutput(processResult.stdout).trim();

    return AgentTaskResult(
      sessionId: parsedSessionId,
      output: output.isEmpty ? rawOutput : output,
      error: processResult.exitCode == 0 ? null : _readError(processResult),
      exitCode: processResult.exitCode,
      rawOutput: rawOutput,
    );
  }

  Future<AgentTaskResult> _runOpenClaw(
    AgentTaskRequest request,
    String prompt,
  ) async {
    final existingSessionId = _usableSessionId(request.conversation);
    final sessionId = existingSessionId ?? _generateUuid();
    final args = [
      '--no-color',
      'agent',
      '--json',
      '--session-id',
      sessionId,
      '--message',
      prompt,
      '--timeout',
      timeout.inSeconds.toString(),
    ];

    final processResult = await _runShellCommand(
      executable: 'openclaw',
      args: args,
      workingDirectory: request.workingDirectory,
    );
    final rawOutput = '${processResult.stdout}\n${processResult.stderr}'.trim();
    final parsedSessionId =
        _extractSessionId(rawOutput) ?? existingSessionId ?? sessionId;
    final output = _extractOutput(processResult.stdout).trim();

    return AgentTaskResult(
      sessionId: parsedSessionId,
      output: output.isEmpty ? rawOutput : output,
      error: processResult.exitCode == 0 ? null : _readError(processResult),
      exitCode: processResult.exitCode,
      rawOutput: rawOutput,
    );
  }

  Future<_CliProcessResult> _runShellCommand({
    required String executable,
    required List<String> args,
    required String workingDirectory,
    String? stdinText,
  }) async {
    final command = [executable, ...args].map(_shellQuote).join(' ');

    try {
      final process = Platform.isWindows
          ? await Process.start(
              'cmd.exe',
              ['/d', '/s', '/c', command],
              workingDirectory: workingDirectory,
              runInShell: false,
            )
          : await Process.start(
              '/bin/zsh',
              ['-lc', command],
              workingDirectory: workingDirectory,
              runInShell: false,
            );

      if (stdinText != null) {
        process.stdin.write(stdinText);
      }
      await process.stdin.close();

      final stdoutFuture = utf8.decoder.bind(process.stdout).join();
      final stderrFuture = utf8.decoder.bind(process.stderr).join();

      int exitCode;
      try {
        exitCode = await process.exitCode.timeout(timeout);
      } on TimeoutException {
        process.kill();
        return _CliProcessResult(
          exitCode: -1,
          stdout: await stdoutFuture,
          stderr: 'Command timed out after ${timeout.inMinutes} minutes.',
        );
      }

      return _CliProcessResult(
        exitCode: exitCode,
        stdout: _stripAnsi(await stdoutFuture),
        stderr: _stripAnsi(await stderrFuture),
      );
    } catch (error) {
      return _CliProcessResult(exitCode: -1, stdout: '', stderr: '$error');
    }
  }
}

class _CliProcessResult {
  const _CliProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

String buildAgentPrompt(AgentTaskRequest request) {
  final instruction = request.instruction.trim().isEmpty
      ? 'Please handle this todo item. Return what you did, the result, and any next steps.'
      : request.instruction.trim();
  final details = request.details.trim().isEmpty
      ? '(No details provided.)'
      : request.details.trim();

  return '''
You are being invoked by Todo Desk for one selected todo item.

Project:
${request.projectName}

Project folder:
${request.projectPath}

Todo title:
${request.title}

Todo details:
$details

User instruction:
$instruction

After processing, return your final response exactly as it should be saved in Todo Desk. Todo Desk saves the final response exactly as returned, so include only the content the user should see. Include changed files, important commands, blockers, and suggested next steps when relevant.
''';
}

String? _usableSessionId(AgentConversation? conversation) {
  final sessionId = conversation?.sessionId.trim();
  if (sessionId == null || sessionId.isEmpty) {
    return null;
  }
  return sessionId;
}

String _readError(_CliProcessResult result) {
  final stderr = result.stderr.trim();
  if (stderr.isNotEmpty) {
    return stderr;
  }
  final stdout = result.stdout.trim();
  if (stdout.isNotEmpty) {
    return stdout;
  }
  return 'Command exited with code ${result.exitCode}.';
}

Future<String> _readOutputFile(File file) async {
  try {
    if (!await file.exists()) {
      return '';
    }
    final output = await file.readAsString();
    unawaited(file.delete());
    return output.trim();
  } catch (_) {
    return '';
  }
}

String _extractOutput(String stdout) {
  final trimmed = stdout.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final jsonText = _tryDecodeJson(trimmed);
  if (jsonText != null) {
    return jsonText;
  }

  final lines = trimmed.split('\n');
  final extracted = <String>[];
  for (final line in lines) {
    final text = _tryDecodeJson(line.trim());
    if (text != null && text.isNotEmpty) {
      extracted.add(text);
    }
  }
  return extracted.isEmpty ? trimmed : extracted.join('\n\n');
}

String? _tryDecodeJson(String text) {
  if (text.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(text);
    return _extractTextFromJson(decoded)?.trim();
  } catch (_) {
    return null;
  }
}

String? _extractTextFromJson(Object? value) {
  if (value is String) {
    return value;
  }
  if (value is List) {
    final pieces = value
        .map(_extractTextFromJson)
        .whereType<String>()
        .where((text) => text.trim().isNotEmpty)
        .toList();
    return pieces.isEmpty ? null : pieces.join('\n');
  }
  if (value is Map) {
    const priorityKeys = [
      'result',
      'response',
      'reply',
      'message',
      'content',
      'text',
      'output',
      'summary',
    ];
    for (final key in priorityKeys) {
      if (value.containsKey(key)) {
        final text = _extractTextFromJson(value[key]);
        if (text != null && text.trim().isNotEmpty) {
          return text;
        }
      }
    }
    for (final entry in value.entries) {
      final key = entry.key.toString().toLowerCase();
      if (key == 'type' || key == 'event' || key.contains('id')) {
        continue;
      }
      final text = _extractTextFromJson(entry.value);
      if (text != null && text.trim().isNotEmpty) {
        return text;
      }
    }
  }
  return null;
}

String? _extractSessionId(String rawOutput) {
  final trimmed = rawOutput.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  for (final line in trimmed.split('\n')) {
    try {
      final decoded = jsonDecode(line.trim());
      final sessionId = _extractSessionIdFromJson(decoded);
      if (sessionId != null) {
        return sessionId;
      }
    } catch (_) {
      // Some CLI output is plain text or mixed JSONL.
    }
  }

  try {
    final decoded = jsonDecode(trimmed);
    final sessionId = _extractSessionIdFromJson(decoded);
    if (sessionId != null) {
      return sessionId;
    }
  } catch (_) {
    // Plain text fallback below.
  }

  final uuidMatch = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  ).firstMatch(trimmed);
  return uuidMatch?.group(0);
}

String? _extractSessionIdFromJson(Object? value) {
  if (value is List) {
    for (final item in value) {
      final sessionId = _extractSessionIdFromJson(item);
      if (sessionId != null) {
        return sessionId;
      }
    }
  }
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString().toLowerCase();
      final entryValue = entry.value;
      if (entryValue is String &&
          key.contains('session') &&
          key.contains('id') &&
          entryValue.trim().isNotEmpty) {
        return entryValue.trim();
      }
    }
    for (final entry in value.entries) {
      final sessionId = _extractSessionIdFromJson(entry.value);
      if (sessionId != null) {
        return sessionId;
      }
    }
  }
  return null;
}

DateTime? _readDateTime(Object? value) {
  if (value is! String) {
    return null;
  }
  return DateTime.tryParse(value);
}

String _generateUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
  final buffer = StringBuffer();
  for (var i = 0; i < bytes.length; i += 1) {
    if (i == 4 || i == 6 || i == 8 || i == 10) {
      buffer.write('-');
    }
    buffer.write(hex(bytes[i]));
  }
  return buffer.toString();
}

String _stripAnsi(String text) {
  return text.replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '');
}

String _shellQuote(String value) {
  if (Platform.isWindows) {
    return _windowsQuote(value);
  }
  return "'${value.replaceAll("'", "'\"'\"'")}'";
}

String _windowsQuote(String value) {
  if (value.isEmpty) {
    return '""';
  }
  final needsQuotes = value.contains(RegExp(r'[\s"&|<>^]'));
  if (!needsQuotes) {
    return value;
  }
  final escaped = value.replaceAll('"', r'\"');
  return '"$escaped"';
}
