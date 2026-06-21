import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'agent_runner.dart';

void main() {
  runApp(TodoApp());
}

const MethodChannel _projectFoldersChannel = MethodChannel(
  'todo_desk/project_folders',
);
const MethodChannel _desktopNotificationsChannel = MethodChannel(
  'todo_desk/notifications',
);

class TodoApp extends StatefulWidget {
  TodoApp({
    super.key,
    TodoStore? store,
    AgentTaskRunner? agentRunner,
    IssueFetcher? issueFetcher,
    DesktopNotificationService? notificationService,
  }) : store = store ?? FileTodoStore(),
       agentRunner = agentRunner ?? const CliAgentTaskRunner(),
       issueFetcher = issueFetcher ?? const HttpIssueFetcher(),
       notificationService =
           notificationService ?? const NativeDesktopNotificationService();

  final TodoStore store;
  final AgentTaskRunner agentRunner;
  final IssueFetcher issueFetcher;
  final DesktopNotificationService notificationService;

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: brightness,
        ).copyWith(
          primary: const Color(0xFF2563EB),
          secondary: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B),
          surface: isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
          surfaceContainerLowest: isDark
              ? const Color(0xFF09090B)
              : const Color(0xFFFDFDFD),
          surfaceContainerLow: isDark
              ? const Color(0xFF18181B)
              : const Color(0xFFF8F8F8),
          surfaceContainer: isDark
              ? const Color(0xFF1F1F23)
              : const Color(0xFFF4F4F5),
          surfaceContainerHigh: isDark
              ? const Color(0xFF27272A)
              : const Color(0xFFF4F4F5),
          surfaceContainerHighest: isDark
              ? const Color(0xFF27272A)
              : const Color(0xFFF4F4F5),
          outline: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8),
          outlineVariant: isDark
              ? const Color(0xFF27272A)
              : const Color(0xFFE4E4E7),
          shadow: Colors.black,
        );

    final baseTextTheme = ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.compact,
      textTheme: baseTextTheme,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(5),
        radius: const Radius.circular(99),
        thumbVisibility: const WidgetStatePropertyAll(true),
        trackVisibility: const WidgetStatePropertyAll(false),
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered)) {
            return scheme.outline;
          }
          return scheme.outlineVariant;
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainer : scheme.surface,
        isDense: true,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: scheme.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: scheme.error),
        ),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
        hintStyle: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          minimumSize: const WidgetStatePropertyAll(Size(0, 30)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        labelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const WidgetStatePropertyAll(EdgeInsets.all(5)),
          minimumSize: const WidgetStatePropertyAll(Size(24, 24)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        side: BorderSide(color: scheme.outline, width: 1.2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      switchTheme: SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
          return null;
        }),
      ),
      tooltipTheme: TooltipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: scheme.onSurface,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: TextStyle(fontSize: 10, color: scheme.surface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Todo Desk',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: TodoHomePage(
        store: widget.store,
        agentRunner: widget.agentRunner,
        issueFetcher: widget.issueFetcher,
        notificationService: widget.notificationService,
        onThemeToggle: _toggleTheme,
      ),
    );
  }
}

enum TodoFilter { all, active, completed }

enum DateFilterMode { today, day, range, all }

enum TodoPriority { high, medium, low }

extension TodoPriorityDetails on TodoPriority {
  String get id {
    return switch (this) {
      TodoPriority.high => 'high',
      TodoPriority.medium => 'medium',
      TodoPriority.low => 'low',
    };
  }

  String get label {
    return switch (this) {
      TodoPriority.high => 'High',
      TodoPriority.medium => 'Medium',
      TodoPriority.low => 'Low',
    };
  }

  IconData get icon {
    return switch (this) {
      TodoPriority.high => Icons.priority_high_rounded,
      TodoPriority.medium => Icons.drag_handle_rounded,
      TodoPriority.low => Icons.low_priority_rounded,
    };
  }

  Color color(ColorScheme colorScheme) {
    return switch (this) {
      TodoPriority.high => colorScheme.error,
      TodoPriority.medium => Colors.amber.shade800,
      TodoPriority.low => Colors.green.shade600,
    };
  }

  static TodoPriority? fromId(String id) {
    for (final priority in TodoPriority.values) {
      if (priority.id == id) {
        return priority;
      }
    }
    return null;
  }
}

enum IssueProvider { gitlab, github }

extension IssueProviderDetails on IssueProvider {
  String get label {
    return switch (this) {
      IssueProvider.gitlab => 'GitLab',
      IssueProvider.github => 'GitHub',
    };
  }
}

class IssueImportSettings {
  const IssueImportSettings({this.gitlabToken = '', this.githubToken = ''});

  final String gitlabToken;
  final String githubToken;

  bool get hasGitlabToken => gitlabToken.trim().isNotEmpty;

  bool get hasGithubToken => githubToken.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {'gitlabToken': gitlabToken, 'githubToken': githubToken};
  }

  factory IssueImportSettings.fromJson(Object? decoded) {
    if (decoded is! Map) {
      return const IssueImportSettings();
    }

    final map = Map<String, dynamic>.from(decoded);
    return IssueImportSettings(
      gitlabToken: map['gitlabToken'] as String? ?? '',
      githubToken: map['githubToken'] as String? ?? '',
    );
  }
}

class AppSettings {
  const AppSettings({
    this.issueImport = const IssueImportSettings(),
    this.agentCompletionNotificationsEnabled = true,
  });

  final IssueImportSettings issueImport;
  final bool agentCompletionNotificationsEnabled;

  AppSettings copyWith({
    IssueImportSettings? issueImport,
    bool? agentCompletionNotificationsEnabled,
  }) {
    return AppSettings(
      issueImport: issueImport ?? this.issueImport,
      agentCompletionNotificationsEnabled:
          agentCompletionNotificationsEnabled ??
          this.agentCompletionNotificationsEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'issueImport': issueImport.toJson(),
      'agentCompletionNotificationsEnabled':
          agentCompletionNotificationsEnabled,
    };
  }

  factory AppSettings.fromJson(Object? decoded) {
    if (decoded is! Map) {
      return const AppSettings();
    }

    final map = Map<String, dynamic>.from(decoded);
    return AppSettings(
      issueImport: IssueImportSettings.fromJson(map['issueImport']),
      agentCompletionNotificationsEnabled:
          map['agentCompletionNotificationsEnabled'] as bool? ?? true,
    );
  }
}

class IssueSnapshot {
  const IssueSnapshot({
    required this.provider,
    required this.url,
    required this.title,
    required this.body,
    required this.projectPath,
    required this.number,
  });

  final IssueProvider provider;
  final String url;
  final String title;
  final String body;
  final String projectPath;
  final int number;
}

abstract class IssueFetcher {
  Future<IssueSnapshot> fetch(String url, IssueImportSettings settings);
}

abstract class DesktopNotificationService {
  Future<bool> show({
    required String title,
    required String body,
    required bool isError,
  });
}

class NativeDesktopNotificationService implements DesktopNotificationService {
  const NativeDesktopNotificationService();

  @override
  Future<bool> show({
    required String title,
    required String body,
    required bool isError,
  }) async {
    try {
      if (Platform.isMacOS) {
        return await _showMacOSNotification(title: title, body: body);
      }
      if (Platform.isWindows) {
        return await _showWindowsNotification(
          title: title,
          body: body,
          isError: isError,
        );
      }
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }

    return false;
  }

  Future<bool> _showMacOSNotification({
    required String title,
    required String body,
  }) async {
    final delivered = await _desktopNotificationsChannel.invokeMethod<bool>(
      'showNotification',
      <String, Object?>{'title': title, 'body': body},
    );
    return delivered ?? false;
  }

  Future<bool> _showWindowsNotification({
    required String title,
    required String body,
    required bool isError,
  }) async {
    final script = r'''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$Title = $env:TODO_DESK_NOTIFICATION_TITLE
$Body = $env:TODO_DESK_NOTIFICATION_BODY
$Icon = $env:TODO_DESK_NOTIFICATION_ICON
$notification = New-Object System.Windows.Forms.NotifyIcon
$notification.Icon = [System.Drawing.SystemIcons]::$Icon
$notification.BalloonTipIcon = $Icon
$notification.BalloonTipTitle = $Title
$notification.BalloonTipText = $Body
$notification.Visible = $true
$notification.ShowBalloonTip(5000)
Start-Sleep -Seconds 6
$notification.Dispose()
''';
    final result = await Process.run(
      'powershell.exe',
      <String>['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
      environment: <String, String>{
        'TODO_DESK_NOTIFICATION_TITLE': title,
        'TODO_DESK_NOTIFICATION_BODY': body,
        'TODO_DESK_NOTIFICATION_ICON': isError ? 'Error' : 'Information',
      },
    );
    return result.exitCode == 0;
  }
}

class TodoData {
  const TodoData({
    required this.projects,
    required this.selectedProjectId,
    this.settings = const AppSettings(),
  });

  final List<TodoProject> projects;
  final String? selectedProjectId;
  final AppSettings settings;

  IssueImportSettings get issueSettings => settings.issueImport;

  TodoData normalized() {
    final normalizedProjects = projects.isEmpty
        ? <TodoProject>[_defaultProject()]
        : projects;
    final hasSelectedProject =
        selectedProjectId != null &&
        normalizedProjects.any((project) => project.id == selectedProjectId);
    return TodoData(
      projects: normalizedProjects,
      selectedProjectId: hasSelectedProject
          ? selectedProjectId
          : normalizedProjects.first.id,
      settings: settings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selectedProjectId': selectedProjectId,
      'projects': projects.map((project) => project.toJson()).toList(),
      'settings': settings.toJson(),
      'issueSettings': issueSettings.toJson(),
    };
  }

  factory TodoData.fromJson(Object? decoded) {
    if (decoded is List) {
      final migratedTodos = _readTodos(decoded);
      final project = _defaultProject().copyWith(todos: migratedTodos);
      return TodoData(
        projects: <TodoProject>[project],
        selectedProjectId: project.id,
        settings: const AppSettings(),
      ).normalized();
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final rawProjects = map['projects'];
      final projects = rawProjects is List
          ? rawProjects
                .whereType<Map>()
                .map(
                  (item) =>
                      TodoProject.fromJson(Map<String, dynamic>.from(item)),
                )
                .where(
                  (project) =>
                      project.id.isNotEmpty &&
                      project.name.isNotEmpty &&
                      project.folderPath.isNotEmpty,
                )
                .toList()
          : <TodoProject>[];
      return TodoData(
        projects: projects,
        selectedProjectId: map['selectedProjectId'] as String?,
        settings: _readAppSettings(map),
      ).normalized();
    }

    return TodoData(
      projects: <TodoProject>[_defaultProject()],
      selectedProjectId: _defaultProject().id,
      settings: const AppSettings(),
    ).normalized();
  }
}

AppSettings _readAppSettings(Map<String, dynamic> map) {
  final decodedSettings = map['settings'];
  if (decodedSettings is Map) {
    return AppSettings.fromJson(decodedSettings);
  }

  return AppSettings(
    issueImport: IssueImportSettings.fromJson(map['issueSettings']),
  );
}

class TodoProject {
  const TodoProject({
    required this.id,
    required this.name,
    required this.folderPath,
    required this.todos,
  });

  final String id;
  final String name;
  final String folderPath;
  final List<TodoItem> todos;

  TodoProject copyWith({
    String? id,
    String? name,
    String? folderPath,
    List<TodoItem>? todos,
  }) {
    return TodoProject(
      id: id ?? this.id,
      name: name ?? this.name,
      folderPath: folderPath ?? this.folderPath,
      todos: todos ?? this.todos,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'folderPath': folderPath,
      'todos': todos.map((todo) => todo.toJson()).toList(),
    };
  }

  factory TodoProject.fromJson(Map<String, dynamic> json) {
    final rawTodos = json['todos'];
    return TodoProject(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      folderPath: json['folderPath'] as String? ?? '',
      todos: rawTodos is List ? _readTodos(rawTodos) : <TodoItem>[],
    );
  }
}

class TodoItem {
  const TodoItem({
    required this.id,
    required this.title,
    required this.details,
    required this.createdAt,
    this.priority = TodoPriority.medium,
    required this.completed,
    required this.conversations,
  });

  final String id;
  final String title;
  final String details;
  final DateTime createdAt;
  final TodoPriority priority;
  final bool completed;
  final Map<AgentKind, AgentConversation> conversations;

  TodoItem copyWith({
    String? id,
    String? title,
    String? details,
    DateTime? createdAt,
    TodoPriority? priority,
    bool? completed,
    Map<AgentKind, AgentConversation>? conversations,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      details: details ?? this.details,
      createdAt: createdAt ?? this.createdAt,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      conversations: conversations ?? this.conversations,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'details': details,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'priority': priority.id,
      'completed': completed,
      'conversations': conversations.map(
        (agent, conversation) => MapEntry(agent.id, conversation.toJson()),
      ),
    };
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    final rawConversations = json['conversations'];
    final conversations = <AgentKind, AgentConversation>{};
    if (rawConversations is Map) {
      for (final entry in rawConversations.entries) {
        final agent = AgentKindDetails.fromId(entry.key.toString());
        final value = entry.value;
        if (agent != null && value is Map) {
          conversations[agent] = AgentConversation.fromJson(
            agent,
            Map<String, dynamic>.from(value),
          );
        }
      }
    }

    return TodoItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      details: json['details'] as String? ?? '',
      createdAt: _readDateTime(json['createdAt'], DateTime.now()),
      priority:
          TodoPriorityDetails.fromId(json['priority'] as String? ?? '') ??
          TodoPriority.medium,
      completed: json['completed'] as bool? ?? false,
      conversations: conversations,
    );
  }
}

abstract class TodoStore {
  Future<TodoData> load();
  Future<void> save(TodoData data);
}

class MemoryTodoStore implements TodoStore {
  MemoryTodoStore([TodoData? seed])
    : _data = (seed ?? _initialData()).normalized();

  TodoData _data;

  @override
  Future<TodoData> load() async {
    return _data.normalized();
  }

  @override
  Future<void> save(TodoData data) async {
    _data = data.normalized();
  }
}

class FileTodoStore implements TodoStore {
  FileTodoStore({Directory? storageDirectory})
    : _storageDirectory = storageDirectory ?? _defaultStorageDirectory();

  final Directory _storageDirectory;

  File get _storageFile =>
      File('${_storageDirectory.path}${Platform.pathSeparator}todos.json');

  @override
  Future<TodoData> load() async {
    try {
      if (!await _storageFile.exists()) {
        return _initialData();
      }

      final raw = await _storageFile.readAsString();
      final decoded = jsonDecode(raw);
      return TodoData.fromJson(decoded);
    } catch (_) {
      return _initialData();
    }
  }

  @override
  Future<void> save(TodoData data) async {
    await _storageDirectory.create(recursive: true);
    await _storageFile.writeAsString(jsonEncode(data.normalized().toJson()));
  }
}

class HttpIssueFetcher implements IssueFetcher {
  const HttpIssueFetcher({this.timeout = const Duration(seconds: 25)});

  final Duration timeout;

  @override
  Future<IssueSnapshot> fetch(String url, IssueImportSettings settings) async {
    final reference = _IssueReference.parse(url);
    final client = HttpClient()..connectionTimeout = timeout;

    try {
      final request = await client.getUrl(reference.apiUri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (reference.provider == IssueProvider.github) {
        request.headers.set(HttpHeaders.userAgentHeader, 'Todo Desk');
        request.headers.set('X-GitHub-Api-Version', '2022-11-28');
        if (settings.hasGithubToken) {
          request.headers.set(
            HttpHeaders.authorizationHeader,
            'Bearer ${settings.githubToken.trim()}',
          );
        }
      } else if (settings.hasGitlabToken) {
        request.headers.set('PRIVATE-TOKEN', settings.gitlabToken.trim());
      }

      final response = await request.close().timeout(timeout);
      final responseBody = await utf8.decodeStream(response).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw IssueFetchException(
          'Could not fetch issue (${response.statusCode}). '
          '${_extractApiMessage(responseBody)}',
        );
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is! Map) {
        throw const IssueFetchException('Issue API returned unexpected data.');
      }

      final issue = Map<String, dynamic>.from(decoded);
      final title = (issue['title'] as String? ?? '').trim();
      if (title.isEmpty) {
        throw const IssueFetchException('Issue title is empty.');
      }

      final body = reference.provider == IssueProvider.gitlab
          ? issue['description'] as String?
          : issue['body'] as String?;
      final webUrl =
          issue['web_url'] as String? ??
          issue['html_url'] as String? ??
          reference.webUri.toString();

      return IssueSnapshot(
        provider: reference.provider,
        url: webUrl,
        title: title,
        body: body?.trim() ?? '',
        projectPath: reference.projectPath,
        number: reference.number,
      );
    } on IssueFetchException {
      rethrow;
    } on FormatException {
      throw const IssueFetchException('Issue API returned invalid JSON.');
    } on TimeoutException {
      throw const IssueFetchException('Issue request timed out.');
    } on SocketException catch (error) {
      throw IssueFetchException('Network error: ${error.message}');
    } finally {
      client.close(force: true);
    }
  }
}

class IssueFetchException implements Exception {
  const IssueFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _IssueReference {
  const _IssueReference({
    required this.provider,
    required this.webUri,
    required this.apiUri,
    required this.projectPath,
    required this.number,
  });

  final IssueProvider provider;
  final Uri webUri;
  final Uri apiUri;
  final String projectPath;
  final int number;

  static _IssueReference parse(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const IssueFetchException('Please enter a valid issue URL.');
    }

    final segments = uri.pathSegments;
    final gitlabIssueIndex = segments.indexOf('issues');
    final dashIndex = segments.indexOf('-');
    if (dashIndex > 0 &&
        gitlabIssueIndex == dashIndex + 1 &&
        segments.length > gitlabIssueIndex + 1) {
      final number = int.tryParse(segments[gitlabIssueIndex + 1]);
      final projectPath = segments.take(dashIndex).join('/');
      if (number != null && projectPath.isNotEmpty) {
        return _IssueReference(
          provider: IssueProvider.gitlab,
          webUri: uri,
          apiUri: uri.replace(
            pathSegments: [
              'api',
              'v4',
              'projects',
              projectPath,
              'issues',
              number.toString(),
            ],
            query: '',
            fragment: '',
          ),
          projectPath: projectPath,
          number: number,
        );
      }
    }

    if ((uri.host == 'github.com' || uri.host == 'www.github.com') &&
        segments.length >= 4 &&
        segments[2] == 'issues') {
      final number = int.tryParse(segments[3]);
      if (number != null) {
        final owner = segments[0];
        final repo = segments[1];
        return _IssueReference(
          provider: IssueProvider.github,
          webUri: uri,
          apiUri: Uri.https(
            'api.github.com',
            '/repos/$owner/$repo/issues/$number',
          ),
          projectPath: '$owner/$repo',
          number: number,
        );
      }
    }

    throw const IssueFetchException(
      'Only GitLab and GitHub issue URLs are supported.',
    );
  }
}

String _extractApiMessage(String responseBody) {
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is Map) {
      final message = decoded['message'] ?? decoded['error_description'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      if (message is Map || message is List) {
        return jsonEncode(message);
      }
    }
  } catch (_) {
    // The status code is already enough when the response is not JSON.
  }
  return responseBody.trim().isEmpty ? '' : responseBody.trim();
}

List<TodoItem> _readTodos(List<Object?> rawTodos) {
  return rawTodos
      .whereType<Object>()
      .map((item) {
        if (item is Map) {
          return TodoItem.fromJson(Map<String, dynamic>.from(item));
        }
        return TodoItem(
          id: '',
          title: '',
          details: '',
          createdAt: DateTime.now(),
          completed: false,
          conversations: const {},
        );
      })
      .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
      .toList();
}

TodoData _initialData() {
  final project = _defaultProject();
  return TodoData(
    projects: <TodoProject>[project],
    selectedProjectId: project.id,
  );
}

TodoProject _defaultProject() {
  return TodoProject(
    id: 'default',
    name: 'Default Project',
    folderPath: Directory.current.path,
    todos: const <TodoItem>[],
  );
}

TodoProject _projectFor(String? projectId, List<TodoProject> projects) {
  if (projects.isEmpty) {
    return _defaultProject();
  }
  if (projectId == null) {
    return projects.first;
  }
  for (final project in projects) {
    if (project.id == projectId) {
      return project;
    }
  }
  return projects.first;
}

String _folderName(String folderPath) {
  final normalized = folderPath.trim().replaceAll('\\', '/');
  final parts = normalized
      .split('/')
      .where((part) => part.trim().isNotEmpty)
      .toList();
  return parts.isEmpty ? folderPath.trim() : parts.last;
}

Future<String?> _pickFolderPath() async {
  try {
    if (Platform.isMacOS) {
      final path = await _projectFoldersChannel.invokeMethod<String>(
        'pickFolder',
      );
      return path == null || path.trim().isEmpty ? null : path.trim();
    }

    if (Platform.isWindows) {
      final script = r'''
$shell = New-Object -ComObject Shell.Application
$folder = $shell.BrowseForFolder(0, "Select project folder", 0)
if ($folder -ne $null) { $folder.Self.Path }
''';
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-STA',
        '-Command',
        script,
      ]);
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        return path.isEmpty ? null : path;
      }
    }
  } catch (_) {
    return null;
  }

  return null;
}

Directory _defaultStorageDirectory() {
  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return Directory('$appData${Platform.pathSeparator}agents_todos');
    }
  } else if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory(
        '$home${Platform.pathSeparator}Library'
        '${Platform.pathSeparator}Application Support'
        '${Platform.pathSeparator}agents_todos',
      );
    }
  }

  final fallback =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.systemTemp.path;
  return Directory('$fallback${Platform.pathSeparator}.agents_todos');
}

String _formatDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final local = value.toLocal();
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

DateTime _readDateTime(Object? rawValue, DateTime fallback) {
  if (rawValue is String) {
    return DateTime.tryParse(rawValue)?.toLocal() ?? fallback;
  }
  return fallback;
}

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime _today() {
  return _dateOnly(DateTime.now());
}

bool _sameDate(DateTime first, DateTime second) {
  final firstDate = _dateOnly(first);
  final secondDate = _dateOnly(second);
  return firstDate.year == secondDate.year &&
      firstDate.month == secondDate.month &&
      firstDate.day == secondDate.day;
}

String _formatDate(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final local = value.toLocal();
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)}';
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({
    super.key,
    required this.store,
    required this.agentRunner,
    required this.issueFetcher,
    required this.notificationService,
    required this.onThemeToggle,
  });

  final TodoStore store;
  final AgentTaskRunner agentRunner;
  final IssueFetcher issueFetcher;
  final DesktopNotificationService notificationService;
  final VoidCallback onThemeToggle;

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _sidebarScrollController = ScrollController();
  final ScrollController _agentScrollController = ScrollController();
  double _agentPanelWidth = 320;
  TodoPriority _quickAddPriority = TodoPriority.medium;

  List<TodoProject> _projects = <TodoProject>[];
  String? _selectedProjectId;
  TodoFilter _filter = TodoFilter.all;
  DateFilterMode _dateFilterMode = DateFilterMode.all;
  DateTime _selectedDate = _today();
  DateTime _rangeStart = _today();
  DateTime _rangeEnd = _today();
  AppSettings _settings = const AppSettings();
  String? _selectedTodoId;
  AgentKind _selectedAgent = AgentKind.codex;
  AgentKind? _runningAgent;
  bool _isLoading = true;
  String? _notice;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTodos());
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    _sidebarScrollController.dispose();
    _agentScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTodos() async {
    try {
      final data = (await widget.store.load()).normalized();
      final project = _projectFor(data.selectedProjectId, data.projects);
      if (!mounted) {
        return;
      }
      setState(() {
        _projects = data.projects;
        _selectedProjectId = project.id;
        _settings = data.settings;
        _selectedTodoId = null;
        _isLoading = false;
        _notice = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        final data = _initialData();
        final project = data.projects.first;
        _projects = data.projects;
        _selectedProjectId = project.id;
        _settings = data.settings;
        _selectedTodoId = null;
        _isLoading = false;
        _notice = 'Could not load saved todos.';
      });
    }
  }

  Future<void> _persistTodos() async {
    try {
      await widget.store.save(
        TodoData(
          projects: _projects,
          selectedProjectId: _selectedProjectId,
          settings: _settings,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _notice = 'Could not save your changes right now.';
      });
    }
  }

  void _addTodo() {
    final title = _controller.text.trim();
    if (title.isEmpty || _selectedProject == null) {
      return;
    }

    _insertTodo(
      _createTodo(title: title, details: '', priority: _quickAddPriority),
    );
    _controller.clear();
    _inputFocusNode.requestFocus();
  }

  TodoItem _createTodo({
    required String title,
    required String details,
    TodoPriority priority = TodoPriority.medium,
  }) {
    final now = DateTime.now();
    return TodoItem(
      id: now.microsecondsSinceEpoch.toString(),
      title: title,
      details: details,
      createdAt: now,
      priority: priority,
      completed: false,
      conversations: {},
    );
  }

  void _insertTodo(TodoItem todo) {
    setState(() {
      _replaceSelectedProjectTodos(<TodoItem>[todo, ..._todos]);
      _selectedTodoId = todo.id;
      _filter = TodoFilter.all;
      _dateFilterMode = DateFilterMode.all;
      _notice = null;
    });

    unawaited(_persistTodos());
  }

  Future<void> _addProject() async {
    final draft = await showDialog<_ProjectDraft>(
      context: context,
      builder: (context) => const _ProjectDialog(),
    );
    if (draft == null) {
      return;
    }

    final project = TodoProject(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: draft.name,
      folderPath: draft.folderPath,
      todos: const <TodoItem>[],
    );

    setState(() {
      _projects = <TodoProject>[..._projects, project];
      _selectedProjectId = project.id;
      _selectedTodoId = null;
      _notice = null;
    });

    unawaited(_persistTodos());
  }

  Future<void> _editProject(TodoProject project) async {
    final draft = await showDialog<_ProjectDraft>(
      context: context,
      builder: (context) => _ProjectDialog(project: project),
    );
    if (draft == null) {
      return;
    }

    setState(() {
      _projects = _projects
          .map(
            (item) => item.id == project.id
                ? item.copyWith(name: draft.name, folderPath: draft.folderPath)
                : item,
          )
          .toList();
      _notice = null;
    });

    unawaited(_persistTodos());
  }

  void _selectProject(String projectId) {
    final project = _projectFor(projectId, _projects);
    setState(() {
      _selectedProjectId = project.id;
      _selectedTodoId = null;
      _filter = TodoFilter.all;
      _dateFilterMode = DateFilterMode.all;
      _selectedDate = _today();
      _rangeStart = _today();
      _rangeEnd = _today();
      _notice = null;
    });

    unawaited(_persistTodos());
  }

  Future<void> _editTodo(TodoItem todo) async {
    final updatedTodo = await showDialog<TodoItem>(
      context: context,
      builder: (context) => _EditTodoDialog(todo: todo),
    );

    if (updatedTodo == null) {
      return;
    }

    setState(() {
      _replaceSelectedProjectTodos(
        _todos
            .map((item) => item.id == updatedTodo.id ? updatedTodo : item)
            .toList(),
      );
    });

    unawaited(_persistTodos());
  }

  void _toggleTodo(TodoItem todo, bool? completed) {
    setState(() {
      _replaceSelectedProjectTodos(
        _todos
            .map(
              (item) => item.id == todo.id
                  ? item.copyWith(completed: completed ?? false)
                  : item,
            )
            .toList(),
      );
      _clearSelectionIfHidden();
    });

    unawaited(_persistTodos());
  }

  void _changeTodoPriority(TodoItem todo, TodoPriority priority) {
    setState(() {
      _replaceSelectedProjectTodos(
        _todos
            .map(
              (item) =>
                  item.id == todo.id ? item.copyWith(priority: priority) : item,
            )
            .toList(),
      );
      _selectedTodoId = todo.id;
      _notice = null;
    });

    unawaited(_persistTodos());
  }

  void _deleteTodo(TodoItem todo) {
    setState(() {
      final updatedTodos = _todos.where((item) => item.id != todo.id).toList();
      _replaceSelectedProjectTodos(updatedTodos);
      _clearSelectionIfHidden();
    });

    unawaited(_persistTodos());
  }

  void _clearSelectedAgentHistory() {
    final selectedTodo = _selectedTodo;
    if (selectedTodo == null) {
      return;
    }

    setState(() {
      _replaceSelectedProjectTodos(
        _todos.map((item) {
          if (item.id != selectedTodo.id) {
            return item;
          }
          final conversations = {...item.conversations};
          conversations.remove(_selectedAgent);
          return item.copyWith(conversations: conversations);
        }).toList(),
      );
      _notice = null;
    });

    unawaited(_persistTodos());
  }

  void _clearCompleted() {
    if (_completedCount == 0) {
      return;
    }

    setState(() {
      final updatedTodos = _todos.where((item) => !item.completed).toList();
      _replaceSelectedProjectTodos(updatedTodos);
      _clearSelectionIfHidden();
    });

    unawaited(_persistTodos());
  }

  void _setDateFilterMode(DateFilterMode mode) {
    setState(() {
      _dateFilterMode = mode;
      if (mode == DateFilterMode.today) {
        _selectedDate = _today();
      }
      _clearSelectionIfHidden();
    });
  }

  Future<void> _openIssueImporter() async {
    final issue = await showDialog<IssueSnapshot>(
      context: context,
      builder: (context) => _IssueImportDialog(
        fetcher: widget.issueFetcher,
        settings: _settings.issueImport,
      ),
    );
    if (issue == null || _selectedProject == null) {
      return;
    }

    final details = [
      '${issue.provider.label} issue: ${issue.url}',
      if (issue.body.trim().isNotEmpty) issue.body.trim(),
    ].join('\n\n');
    _insertTodo(_createTodo(title: issue.title, details: details));
  }

  Future<void> _openSettings() async {
    final settings = await showDialog<AppSettings>(
      context: context,
      builder: (context) => _SettingsDialog(settings: _settings),
    );
    if (settings == null) {
      return;
    }

    setState(() {
      _settings = settings;
      _notice = null;
    });
    unawaited(_persistTodos());
  }

  Future<void> _pickSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _dateFilterMode = DateFilterMode.day;
      _selectedDate = _dateOnly(picked);
      _clearSelectionIfHidden();
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _dateFilterMode = DateFilterMode.range;
      _rangeStart = _dateOnly(picked.start);
      _rangeEnd = _dateOnly(picked.end);
      _clearSelectionIfHidden();
    });
  }

  Future<void> _sendToAgent(
    TodoItem todo,
    String instruction, {
    bool continueSession = true,
  }) async {
    if (_runningAgent != null) {
      return;
    }

    final agent = _selectedAgent;
    final project = _selectedProject;
    if (project == null) {
      return;
    }

    final workingDirectory = project.folderPath.trim();
    if (!Directory(workingDirectory).existsSync()) {
      setState(() {
        _notice = 'Project folder does not exist: $workingDirectory';
      });
      return;
    }

    final startedAt = DateTime.now();

    setState(() {
      _runningAgent = agent;
      _notice = '${agent.label} is handling "${todo.title}".';
    });

    final result = await widget.agentRunner.run(
      AgentTaskRequest(
        agent: agent,
        title: todo.title,
        details: todo.details,
        instruction: instruction,
        conversation: continueSession ? todo.conversations[agent] : null,
        workingDirectory: workingDirectory,
        projectName: project.name,
        projectPath: project.folderPath,
      ),
    );

    if (!mounted) {
      return;
    }

    final finishedAt = DateTime.now();
    final run = AgentRun(
      id: finishedAt.microsecondsSinceEpoch.toString(),
      agentId: agent.id,
      instruction: instruction,
      output: result.output.trim(),
      error: result.error,
      exitCode: result.exitCode,
      startedAt: startedAt,
      finishedAt: finishedAt,
    );

    final completionMessage = run.succeeded
        ? '${agent.label} finished "${todo.title}".'
        : '${agent.label} returned an error.';
    final notificationTitle = run.succeeded
        ? '${agent.label} completed a todo'
        : '${agent.label} needs attention';
    final notificationBody = run.succeeded
        ? '"${todo.title}" finished successfully. Result saved in Todo Desk.'
        : '"${todo.title}" returned an error. Open Todo Desk to review the run.';

    setState(() {
      _replaceSelectedProjectTodos(
        _todos.map((item) {
          if (item.id != todo.id) {
            return item;
          }
          final existing = item.conversations[agent];
          final sessionId =
              result.sessionId ??
              (continueSession ? existing?.sessionId : null) ??
              '';
          final updatedConversation = AgentConversation(
            agent: agent,
            sessionId: sessionId,
            updatedAt: finishedAt,
            runs: continueSession
                ? <AgentRun>[run, ...?existing?.runs]
                : <AgentRun>[run],
          );
          return item.copyWith(
            conversations: {...item.conversations, agent: updatedConversation},
          );
        }).toList(),
      );
      _runningAgent = null;
      _notice = completionMessage;
    });
    if (_settings.agentCompletionNotificationsEnabled) {
      unawaited(
        _showAgentCompletionNotification(
          title: notificationTitle,
          body: notificationBody,
          isError: !run.succeeded,
        ),
      );
    }

    unawaited(_persistTodos());
  }

  Future<void> _showAgentCompletionNotification({
    required String title,
    required String body,
    required bool isError,
  }) async {
    final delivered = await widget.notificationService.show(
      title: title,
      body: body,
      isError: isError,
    );
    if (!mounted || delivered) {
      return;
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: isError
            ? colorScheme.errorContainer
            : colorScheme.inverseSurface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isError
                    ? colorScheme.onErrorContainer
                    : colorScheme.onInverseSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isError
                    ? colorScheme.onErrorContainer
                    : colorScheme.onInverseSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TodoItem> get _visibleTodos {
    final todos = _dateFilteredTodos;
    switch (_filter) {
      case TodoFilter.active:
        return todos.where((item) => !item.completed).toList();
      case TodoFilter.completed:
        return todos.where((item) => item.completed).toList();
      case TodoFilter.all:
        return todos;
    }
  }

  List<TodoItem> get _dateFilteredTodos {
    return _todos.where(_matchesDateFilter).toList();
  }

  bool _matchesDateFilter(TodoItem todo) {
    final createdDate = _dateOnly(todo.createdAt);
    switch (_dateFilterMode) {
      case DateFilterMode.today:
        return _sameDate(createdDate, _today());
      case DateFilterMode.day:
        return _sameDate(createdDate, _selectedDate);
      case DateFilterMode.range:
        final start = _dateOnly(_rangeStart);
        final end = _dateOnly(_rangeEnd);
        return !createdDate.isBefore(start) && !createdDate.isAfter(end);
      case DateFilterMode.all:
        return true;
    }
  }

  int get _openCount =>
      _dateFilteredTodos.where((item) => !item.completed).length;

  int get _completedCount =>
      _dateFilteredTodos.where((item) => item.completed).length;

  List<TodoItem> get _todos => _selectedProject?.todos ?? const <TodoItem>[];

  TodoProject? get _selectedProject {
    final selectedProjectId = _selectedProjectId;
    if (selectedProjectId == null) {
      return _projects.isEmpty ? null : _projects.first;
    }
    return _projectFor(selectedProjectId, _projects);
  }

  TodoItem? get _selectedTodo {
    final selectedTodoId = _selectedTodoId;
    if (selectedTodoId == null) {
      return null;
    }
    for (final todo in _todos) {
      if (todo.id == selectedTodoId) {
        return todo;
      }
    }
    return null;
  }

  void _clearSelectionIfHidden() {
    final selectedTodoId = _selectedTodoId;
    if (selectedTodoId == null) {
      return;
    }
    if (_visibleTodos.any((item) => item.id == selectedTodoId)) {
      return;
    }
    _selectedTodoId = null;
  }

  void _replaceSelectedProjectTodos(List<TodoItem> todos) {
    final selectedProject = _selectedProject;
    if (selectedProject == null) {
      return;
    }
    _projects = _projects
        .map(
          (project) => project.id == selectedProject.id
              ? project.copyWith(todos: todos)
              : project,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleTodos = _visibleTodos;
    final selectedTodo = _selectedTodo;
    final selectedProject = _selectedProject;
    final notice = _notice;
    final totalOpen = _openCount;
    final totalDone = _completedCount;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 1080;
            final agentPanelWidth = isCompact
                ? constraints.maxWidth
                : _agentPanelWidth.clamp(260.0, 520.0).toDouble();

            return Column(
              children: [
                _TitleBar(
                  projectName: selectedProject?.name,
                  openCount: totalOpen,
                  doneCount: totalDone,
                  themeMode: Theme.of(context).brightness,
                  onToggleTheme: widget.onThemeToggle,
                  onOpenSettings: _isLoading ? null : _openSettings,
                  onOpenIssue: _isLoading || selectedProject == null
                      ? null
                      : _openIssueImporter,
                ),
                Expanded(
                  child: Row(
                    children: [
                      _Sidebar(
                        scrollController: _sidebarScrollController,
                        projects: _projects,
                        selectedProject: selectedProject,
                        isLoading: _isLoading,
                        notice: notice,
                        onProjectSelected: _selectProject,
                        onAddProject: _addProject,
                        onEditProject: selectedProject == null
                            ? null
                            : _editProject,
                        onShowAll: () {
                          setState(() {
                            _dateFilterMode = DateFilterMode.all;
                            _filter = TodoFilter.all;
                            _clearSelectionIfHidden();
                          });
                        },
                        onShowToday: () {
                          setState(() {
                            _dateFilterMode = DateFilterMode.today;
                            _selectedDate = _today();
                            _clearSelectionIfHidden();
                          });
                        },
                        onClearCompleted: _clearCompleted,
                      ),
                      Expanded(
                        child: _MainWorkspace(
                          project: selectedProject,
                          isLoading: _isLoading,
                          dateFilterMode: _dateFilterMode,
                          selectedDate: _selectedDate,
                          rangeStart: _rangeStart,
                          rangeEnd: _rangeEnd,
                          filter: _filter,
                          visibleTodos: visibleTodos,
                          selectedTodoId: _selectedTodoId,
                          scrollController: _scrollController,
                          onAddTodo: _addTodo,
                          addController: _controller,
                          addFocusNode: _inputFocusNode,
                          selectedPriority: _quickAddPriority,
                          onQuickAddPriorityChanged: (priority) {
                            setState(() {
                              _quickAddPriority = priority;
                            });
                          },
                          onFilterChanged: (filter) {
                            setState(() {
                              _filter = filter;
                              _clearSelectionIfHidden();
                            });
                          },
                          onDateModeChanged: _setDateFilterMode,
                          onPickSingleDate: _pickSingleDate,
                          onPickDateRange: _pickDateRange,
                          onSelectTodo: (todo) {
                            setState(() {
                              _selectedTodoId = todo.id;
                            });
                          },
                          onToggleTodo: _toggleTodo,
                          onPriorityChanged: _changeTodoPriority,
                          onEditTodo: _editTodo,
                          onDeleteTodo: _deleteTodo,
                        ),
                      ),
                      if (!isCompact) ...[
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _agentPanelWidth =
                                  (_agentPanelWidth - details.delta.dx)
                                      .clamp(260.0, 520.0)
                                      .toDouble();
                            });
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeLeftRight,
                            child: Container(
                              width: 4,
                              color: Colors.transparent,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: agentPanelWidth,
                          child: _AgentWorkspace(
                            scrollController: _agentScrollController,
                            todo: selectedTodo,
                            selectedAgent: _selectedAgent,
                            runningAgent: _runningAgent,
                            onAgentChanged: (agent) {
                              setState(() {
                                _selectedAgent = agent;
                              });
                            },
                            onRun: selectedTodo == null
                                ? null
                                : (instruction, {continueSession = true}) =>
                                      _sendToAgent(
                                        selectedTodo,
                                        instruction,
                                        continueSession: continueSession,
                                      ),
                            onStop: () {},
                            onClearHistory: selectedTodo == null
                                ? null
                                : _clearSelectedAgentHistory,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isCompact)
                  SizedBox(
                    height: 380,
                    child: _AgentWorkspace(
                      scrollController: _agentScrollController,
                      todo: selectedTodo,
                      selectedAgent: _selectedAgent,
                      runningAgent: _runningAgent,
                      onAgentChanged: (agent) {
                        setState(() {
                          _selectedAgent = agent;
                        });
                      },
                      onRun: selectedTodo == null
                          ? null
                          : (instruction, {continueSession = true}) =>
                                _sendToAgent(
                                  selectedTodo,
                                  instruction,
                                  continueSession: continueSession,
                                ),
                      onStop: () {},
                      onClearHistory: selectedTodo == null
                          ? null
                          : _clearSelectedAgentHistory,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DateFilterControl extends StatelessWidget {
  const _DateFilterControl({
    required this.mode,
    required this.selectedDate,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onModeChanged,
    required this.onPickSingleDate,
    required this.onPickDateRange,
  });

  final DateFilterMode mode;
  final DateTime selectedDate;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final ValueChanged<DateFilterMode> onModeChanged;
  final VoidCallback onPickSingleDate;
  final VoidCallback onPickDateRange;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _MiniSegmentedButton<DateFilterMode>(
          selectedValue: mode,
          onChanged: onModeChanged,
          items: const [
            _MiniSegmentItem<DateFilterMode>(
              value: DateFilterMode.all,
              label: '全部',
              icon: Icons.event_available_outlined,
            ),
            _MiniSegmentItem<DateFilterMode>(
              value: DateFilterMode.today,
              label: '今天',
              icon: Icons.today_outlined,
            ),
            _MiniSegmentItem<DateFilterMode>(
              value: DateFilterMode.day,
              label: '指定日期',
              icon: Icons.calendar_month_outlined,
            ),
            _MiniSegmentItem<DateFilterMode>(
              value: DateFilterMode.range,
              label: '日期范围',
              icon: Icons.date_range_outlined,
            ),
          ],
        ),
        if (mode == DateFilterMode.day)
          OutlinedButton.icon(
            onPressed: onPickSingleDate,
            icon: const Icon(Icons.edit_calendar_outlined),
            label: Text(_formatDate(selectedDate)),
          ),
        if (mode == DateFilterMode.range)
          OutlinedButton.icon(
            onPressed: onPickDateRange,
            icon: const Icon(Icons.edit_calendar_outlined),
            label: Text(
              '${_formatDate(rangeStart)} - ${_formatDate(rangeEnd)}',
            ),
          ),
      ],
    );
  }
}

class _TodoPrioritySection extends StatelessWidget {
  const _TodoPrioritySection({
    required this.priority,
    required this.todos,
    required this.selectedTodoId,
    required this.onSelectTodo,
    required this.onToggleTodo,
    required this.onPriorityChanged,
    required this.onEditTodo,
    required this.onDeleteTodo,
  });

  final TodoPriority priority;
  final List<TodoItem> todos;
  final String? selectedTodoId;
  final ValueChanged<TodoItem> onSelectTodo;
  final void Function(TodoItem todo, bool? completed) onToggleTodo;
  final void Function(TodoItem todo, TodoPriority priority) onPriorityChanged;
  final ValueChanged<TodoItem> onEditTodo;
  final ValueChanged<TodoItem> onDeleteTodo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final priorityColor = priority.color(colorScheme);

    return DragTarget<TodoItem>(
      onWillAcceptWithDetails: (details) {
        return details.data.priority != priority;
      },
      onAcceptWithDetails: (details) {
        onPriorityChanged(details.data, priority);
      },
      builder: (context, candidateTodos, rejectedTodos) {
        final isTargeted = candidateTodos.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: isTargeted
                ? priorityColor.withValues(alpha: 0.08)
                : colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 5, 12, 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: priorityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${priority.label} priority',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          letterSpacing: 0.6,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${todos.length})',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: todos.map((todo) {
                  return _TodoTile(
                    todo: todo,
                    isSelected: todo.id == selectedTodoId,
                    onSelectTodo: onSelectTodo,
                    onToggleTodo: onToggleTodo,
                    onEditTodo: onEditTodo,
                    onDeleteTodo: onDeleteTodo,
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TodoTile extends StatefulWidget {
  const _TodoTile({
    required this.todo,
    required this.isSelected,
    required this.onSelectTodo,
    required this.onToggleTodo,
    required this.onEditTodo,
    required this.onDeleteTodo,
  });

  final TodoItem todo;
  final bool isSelected;
  final ValueChanged<TodoItem> onSelectTodo;
  final void Function(TodoItem todo, bool? completed) onToggleTodo;
  final ValueChanged<TodoItem> onEditTodo;
  final ValueChanged<TodoItem> onDeleteTodo;

  @override
  State<_TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends State<_TodoTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = widget.todo.completed;
    final priorityColor = widget.todo.priority.color(colorScheme);
    final isDark = theme.brightness == Brightness.dark;
    final showInlineTools = _isHovered || widget.isSelected;

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.28)
              : colorScheme.surface,
          border: Border(
            left: BorderSide(
              color: widget.isSelected
                  ? colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
            bottom: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onSelectTodo(widget.todo),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                widget.isSelected ? 10 : 12,
                8,
                12,
                8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Draggable<TodoItem>(
                    data: widget.todo,
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: _TodoDragPreview(todo: widget.todo),
                    childWhenDragging: Opacity(
                      opacity: 0.35,
                      child: _DragHandle(
                        color: colorScheme.onSurfaceVariant,
                        visible: true,
                      ),
                    ),
                    child: _DragHandle(
                      color: colorScheme.onSurfaceVariant,
                      visible: showInlineTools,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Checkbox(
                    value: isCompleted,
                    onChanged: (value) =>
                        widget.onToggleTodo(widget.todo, value),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.todo.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: isCompleted
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSurface,
                            ),
                          ),
                          if (widget.todo.details.trim().isNotEmpty) ...[
                            const SizedBox(height: 1),
                            Text(
                              widget.todo.details.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _formatDate(widget.todo.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.78),
                                  fontSize: 10,
                                ),
                              ),
                              _InlineChip(
                                label: widget.todo.priority.label,
                                backgroundColor: priorityColor.withValues(
                                  alpha: isDark ? 0.18 : 0.09,
                                ),
                                foregroundColor: priorityColor,
                                borderColor: priorityColor.withValues(
                                  alpha: isDark ? 0.45 : 0.25,
                                ),
                                fontSize: 10,
                              ),
                              for (final conversation
                                  in widget.todo.conversations.values)
                                _InlineChip(
                                  label: conversation.sessionId.trim().isEmpty
                                      ? conversation.agent.label
                                      : conversation.sessionId,
                                  backgroundColor: colorScheme.primaryContainer
                                      .withValues(alpha: 0.28),
                                  foregroundColor: colorScheme.primary,
                                  borderColor: colorScheme.primary.withValues(
                                    alpha: 0.24,
                                  ),
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: showInlineTools ? 1 : 0,
                    duration: const Duration(milliseconds: 100),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit todo',
                          onPressed: () => widget.onEditTodo(widget.todo),
                          icon: const Icon(Icons.edit_outlined, size: 13),
                          color: colorScheme.onSurfaceVariant,
                        ),
                        IconButton(
                          tooltip: 'Delete todo',
                          onPressed: () => widget.onDeleteTodo(widget.todo),
                          icon: const Icon(Icons.delete_outline, size: 13),
                          color: colorScheme.error,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color, required this.visible});

  final Color color;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Move priority',
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: 20,
          height: 28,
          child: Icon(Icons.drag_indicator_rounded, size: 14, color: color),
        ),
      ),
    );
  }
}

class _TodoDragPreview extends StatelessWidget {
  const _TodoDragPreview({required this.todo});

  final TodoItem todo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: todo.priority.color(colorScheme)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              todo.priority.icon,
              size: 16,
              color: todo.priority.color(colorScheme),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                todo.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.projectName,
    required this.openCount,
    required this.doneCount,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onOpenSettings,
    required this.onOpenIssue,
  });

  final String? projectName;
  final int openCount;
  final int doneCount;
  final Brightness themeMode;
  final VoidCallback onToggleTheme;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenIssue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Row(
              children: const [
                _WindowDot(color: Color(0xFFFF5F57)),
                SizedBox(width: 5),
                _WindowDot(color: Color(0xFFFFBD2E)),
                SizedBox(width: 5),
                _WindowDot(color: Color(0xFF28CA41)),
              ],
            ),
          ),
          Text(
            'Todo Desk',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (projectName != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '— $projectName',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const Spacer(),
          _HeaderStat(
            label: 'Open',
            value: openCount.toString(),
            accentColor: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          _HeaderStat(
            label: 'Done',
            value: doneCount.toString(),
            accentColor: Colors.green.shade600,
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: themeMode == Brightness.dark
                ? 'Light theme'
                : 'Dark theme',
            onPressed: onToggleTheme,
            icon: Icon(
              themeMode == Brightness.dark
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              size: 14,
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined, size: 14),
          ),
          IconButton(
            tooltip: 'Import issue',
            onPressed: onOpenIssue,
            icon: const Icon(Icons.add_link_outlined, size: 14),
          ),
        ],
      ),
    );
  }
}

class _WindowDot extends StatelessWidget {
  const _WindowDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineChip extends StatelessWidget {
  const _InlineChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    this.fontSize = 10,
    this.fontFamily,
    this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final double fontSize;
  final String? fontFamily;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      color: foregroundColor,
      fontFamily: fontFamily,
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: foregroundColor),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSegmentItem<T> {
  const _MiniSegmentItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

class _MiniSegmentedButton<T> extends StatelessWidget {
  const _MiniSegmentedButton({
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    this.expand = false,
  });

  final List<_MiniSegmentItem<T>> items;
  final T selectedValue;
  final ValueChanged<T>? onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final disabled = onChanged == null;

    final children = items.map((item) {
      final selected = item.value == selectedValue;
      final segment = AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: disabled ? null : () => onChanged!(item.value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Opacity(opacity: 0, child: Icon(item.icon, size: 13)),
                ],
              ),
            ),
          ),
        ),
      );

      if (expand) {
        return Expanded(child: segment);
      }
      return segment;
    }).toList();

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const SizedBox(width: 1),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _DialogSection extends StatelessWidget {
  const _DialogSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.scrollController,
    required this.projects,
    required this.selectedProject,
    required this.isLoading,
    required this.notice,
    required this.onProjectSelected,
    required this.onAddProject,
    required this.onEditProject,
    required this.onShowAll,
    required this.onShowToday,
    required this.onClearCompleted,
  });

  final ScrollController scrollController;
  final List<TodoProject> projects;
  final TodoProject? selectedProject;
  final bool isLoading;
  final String? notice;
  final ValueChanged<String> onProjectSelected;
  final VoidCallback onAddProject;
  final Future<void> Function(TodoProject)? onEditProject;
  final VoidCallback onShowAll;
  final VoidCallback onShowToday;
  final VoidCallback onClearCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              children: [
                _SidebarSectionHeader(
                  title: '项目',
                  action: IconButton(
                    tooltip: 'New project',
                    onPressed: isLoading ? null : onAddProject,
                    icon: const Icon(Icons.add, size: 12),
                  ),
                ),
                if (projects.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '暂无项目',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  ...projects.map(
                    (project) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _SidebarProjectItem(
                        project: project,
                        selected: project.id == selectedProject?.id,
                        onTap: () => onProjectSelected(project.id),
                        onEdit: onEditProject == null
                            ? null
                            : () => unawaited(onEditProject!(project)),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                const _SidebarSectionHeader(title: '快速操作'),
                _SidebarActionItem(
                  icon: Icons.list_outlined,
                  label: '所有任务',
                  selected: false,
                  onTap: onShowAll,
                ),
                _SidebarActionItem(
                  icon: Icons.calendar_month_outlined,
                  label: '今天',
                  selected: false,
                  onTap: onShowToday,
                ),
                _SidebarActionItem(
                  icon: Icons.dashboard_outlined,
                  label: '工作台',
                  selected: true,
                  onTap: () {},
                ),
                const _SidebarSectionHeader(title: '当前项目路径'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    selectedProject?.folderPath ?? '未选择项目',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (notice != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        border: Border.all(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        notice!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : onClearCompleted,
              icon: const Icon(Icons.checklist_outlined),
              label: const Text('清除已完成'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  const _SidebarSectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              letterSpacing: 0,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          ?action,
        ],
      ),
    );
  }
}

class _SidebarProjectItem extends StatelessWidget {
  const _SidebarProjectItem({
    required this.project,
    required this.selected,
    required this.onTap,
    required this.onEdit,
  });

  final TodoProject project;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  project.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 10),
                tooltip: 'Edit project',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarActionItem extends StatelessWidget {
  const _SidebarActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.28)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MainWorkspace extends StatelessWidget {
  const _MainWorkspace({
    required this.project,
    required this.isLoading,
    required this.dateFilterMode,
    required this.selectedDate,
    required this.rangeStart,
    required this.rangeEnd,
    required this.filter,
    required this.visibleTodos,
    required this.selectedTodoId,
    required this.scrollController,
    required this.onAddTodo,
    required this.addController,
    required this.addFocusNode,
    required this.selectedPriority,
    required this.onQuickAddPriorityChanged,
    required this.onFilterChanged,
    required this.onDateModeChanged,
    required this.onPickSingleDate,
    required this.onPickDateRange,
    required this.onSelectTodo,
    required this.onToggleTodo,
    required this.onPriorityChanged,
    required this.onEditTodo,
    required this.onDeleteTodo,
  });

  final TodoProject? project;
  final bool isLoading;
  final DateFilterMode dateFilterMode;
  final DateTime selectedDate;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final TodoFilter filter;
  final List<TodoItem> visibleTodos;
  final String? selectedTodoId;
  final ScrollController scrollController;
  final VoidCallback onAddTodo;
  final TextEditingController addController;
  final FocusNode addFocusNode;
  final TodoPriority selectedPriority;
  final ValueChanged<TodoPriority> onQuickAddPriorityChanged;
  final ValueChanged<TodoFilter> onFilterChanged;
  final ValueChanged<DateFilterMode> onDateModeChanged;
  final VoidCallback onPickSingleDate;
  final VoidCallback onPickDateRange;
  final ValueChanged<TodoItem> onSelectTodo;
  final void Function(TodoItem todo, bool? completed) onToggleTodo;
  final void Function(TodoItem todo, TodoPriority priority) onPriorityChanged;
  final ValueChanged<TodoItem> onEditTodo;
  final ValueChanged<TodoItem> onDeleteTodo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WorkspaceToolbar(
            project: project,
            dateFilterMode: dateFilterMode,
            selectedDate: selectedDate,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            filter: filter,
            isLoading: isLoading,
            addController: addController,
            addFocusNode: addFocusNode,
            selectedPriority: selectedPriority,
            onAddTodo: onAddTodo,
            onQuickAddPriorityChanged: onQuickAddPriorityChanged,
            onFilterChanged: onFilterChanged,
            onDateModeChanged: onDateModeChanged,
            onPickSingleDate: onPickSingleDate,
            onPickDateRange: onPickDateRange,
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : visibleTodos.isEmpty
                ? _EmptyState(
                    filter: filter,
                    dateLabel: _dateLabelFromMode(
                      dateFilterMode,
                      selectedDate,
                      rangeStart,
                      rangeEnd,
                    ),
                  )
                : Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        for (final priority in TodoPriority.values)
                          _TodoPrioritySection(
                            priority: priority,
                            todos: visibleTodos
                                .where((todo) => todo.priority == priority)
                                .toList(),
                            selectedTodoId: selectedTodoId,
                            onSelectTodo: onSelectTodo,
                            onToggleTodo: onToggleTodo,
                            onPriorityChanged: onPriorityChanged,
                            onEditTodo: onEditTodo,
                            onDeleteTodo: onDeleteTodo,
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String _dateLabelFromMode(
  DateFilterMode mode,
  DateTime selectedDate,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  switch (mode) {
    case DateFilterMode.today:
      return 'Today';
    case DateFilterMode.day:
      return _formatDate(selectedDate);
    case DateFilterMode.range:
      return '${_formatDate(rangeStart)} to ${_formatDate(rangeEnd)}';
    case DateFilterMode.all:
      return 'All dates';
  }
}

class _WorkspaceToolbar extends StatelessWidget {
  const _WorkspaceToolbar({
    required this.project,
    required this.dateFilterMode,
    required this.selectedDate,
    required this.rangeStart,
    required this.rangeEnd,
    required this.filter,
    required this.isLoading,
    required this.addController,
    required this.addFocusNode,
    required this.selectedPriority,
    required this.onAddTodo,
    required this.onQuickAddPriorityChanged,
    required this.onFilterChanged,
    required this.onDateModeChanged,
    required this.onPickSingleDate,
    required this.onPickDateRange,
  });

  final TodoProject? project;
  final DateFilterMode dateFilterMode;
  final DateTime selectedDate;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final TodoFilter filter;
  final bool isLoading;
  final TextEditingController addController;
  final FocusNode addFocusNode;
  final TodoPriority selectedPriority;
  final VoidCallback onAddTodo;
  final ValueChanged<TodoPriority> onQuickAddPriorityChanged;
  final ValueChanged<TodoFilter> onFilterChanged;
  final ValueChanged<DateFilterMode> onDateModeChanged;
  final VoidCallback onPickSingleDate;
  final VoidCallback onPickDateRange;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canAdd = !isLoading && project != null;
    final quickAdd = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300, minWidth: 300),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              textField: true,
              label: 'New task',
              child: TextField(
                controller: addController,
                focusNode: addFocusNode,
                enabled: canAdd,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAddTodo(),
                decoration: const InputDecoration(
                  hintText: '新增任务，按 Enter 确认...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 90,
            child: DropdownButtonFormField<TodoPriority>(
              initialValue: selectedPriority,
              isExpanded: true,
              items: TodoPriority.values
                  .map(
                    (priority) => DropdownMenuItem<TodoPriority>(
                      value: priority,
                      child: Text(priority.label),
                    ),
                  )
                  .toList(),
              onChanged: canAdd
                  ? (priority) {
                      if (priority != null) {
                        onQuickAddPriorityChanged(priority);
                      }
                    }
                  : null,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: canAdd ? onAddTodo : null,
            icon: const Icon(Icons.add_rounded, size: 11),
            label: const Text('添加'),
          ),
        ],
      ),
    );

    final filters = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DateFilterControl(
          mode: dateFilterMode,
          selectedDate: selectedDate,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          onModeChanged: onDateModeChanged,
          onPickSingleDate: onPickSingleDate,
          onPickDateRange: onPickDateRange,
        ),
        const _ToolbarDivider(),
        _MiniSegmentedButton<TodoFilter>(
          selectedValue: filter,
          onChanged: onFilterChanged,
          items: const [
            _MiniSegmentItem<TodoFilter>(
              value: TodoFilter.all,
              label: '全部',
              icon: Icons.list_alt_outlined,
            ),
            _MiniSegmentItem<TodoFilter>(
              value: TodoFilter.active,
              label: 'Open',
              icon: Icons.radio_button_unchecked_outlined,
            ),
            _MiniSegmentItem<TodoFilter>(
              value: TodoFilter.completed,
              label: 'Done',
              icon: Icons.check_circle_outline,
            ),
          ],
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          if (compact) {
            return Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [quickAdd, filters],
            );
          }

          return Row(
            children: [
              quickAdd,
              const _ToolbarDivider(),
              Flexible(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: filters,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AgentWorkspace extends StatefulWidget {
  const _AgentWorkspace({
    required this.todo,
    required this.selectedAgent,
    required this.runningAgent,
    required this.onAgentChanged,
    required this.onRun,
    required this.scrollController,
    this.onStop,
    this.onClearHistory,
  });

  final TodoItem? todo;
  final AgentKind selectedAgent;
  final AgentKind? runningAgent;
  final ValueChanged<AgentKind> onAgentChanged;
  final Future<void> Function(String instruction, {bool continueSession})?
  onRun;
  final ScrollController scrollController;
  final VoidCallback? onStop;
  final VoidCallback? onClearHistory;

  @override
  State<_AgentWorkspace> createState() => _AgentWorkspaceState();
}

class _AgentWorkspaceState extends State<_AgentWorkspace> {
  final TextEditingController _instructionController = TextEditingController(
    text: 'Please handle this todo and report the result.',
  );
  final TextEditingController _sessionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncSessionController();
  }

  @override
  void didUpdateWidget(covariant _AgentWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todo?.id != widget.todo?.id ||
        oldWidget.selectedAgent != widget.selectedAgent) {
      _syncSessionController();
    }
  }

  @override
  void dispose() {
    _instructionController.dispose();
    _sessionController.dispose();
    super.dispose();
  }

  void _syncSessionController() {
    final sessionId =
        widget.todo?.conversations[widget.selectedAgent]?.sessionId ?? '';
    if (_sessionController.text != sessionId) {
      _sessionController.text = sessionId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final todo = widget.todo;
    final conversation = todo?.conversations[widget.selectedAgent];
    final isRunning = widget.runningAgent != null;

    final canRun = todo != null && !isRunning && widget.onRun != null;
    final canContinue = canRun && conversation != null;
    final priorityColor =
        todo?.priority.color(colorScheme) ?? colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(left: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Agent 工作台',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'About agents',
                      onPressed: () {},
                      icon: const Icon(Icons.help_outline, size: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: todo == null
                      ? Text(
                          '未选择任务 — 点击左侧 Todo 以选中',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              todo.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _InlineChip(
                              label: todo.priority.label,
                              backgroundColor: priorityColor.withValues(
                                alpha: isDark ? 0.18 : 0.09,
                              ),
                              foregroundColor: priorityColor,
                              borderColor: priorityColor.withValues(
                                alpha: isDark ? 0.45 : 0.25,
                              ),
                              fontSize: 10,
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  '选择 Agent',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<AgentKind>(
                  initialValue: widget.selectedAgent,
                  isExpanded: true,
                  items: AgentKind.values
                      .map(
                        (agent) => DropdownMenuItem<AgentKind>(
                          value: agent,
                          child: Text(agent.label),
                        ),
                      )
                      .toList(),
                  onChanged: isRunning
                      ? null
                      : (agent) {
                          if (agent != null) {
                            widget.onAgentChanged(agent);
                          }
                        },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 7,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _instructionController,
                  enabled: todo != null && !isRunning,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Instruction',
                    alignLabelWithHint: true,
                    hintText: 'Describe what the agent should do...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sessionController,
                        enabled: false,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Session ID',
                          hintText: 'Leave blank to create a new session',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    OutlinedButton(
                      onPressed: isRunning
                          ? null
                          : () {
                              _sessionController.clear();
                            },
                      child: const Text('新会话'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: canRun
                            ? () => widget.onRun!(
                                _instructionController.text,
                                continueSession: false,
                              )
                            : null,
                        icon: const Icon(Icons.send_outlined, size: 12),
                        label: const Text('Send to agent'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: canContinue
                            ? () => widget.onRun!(
                                _instructionController.text,
                                continueSession: true,
                              )
                            : null,
                        icon: const Icon(Icons.rotate_left_outlined, size: 12),
                        label: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
                if (isRunning) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Agent 执行中...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onStop,
                        child: const Text('停止'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '历史记录',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Clear history',
                  onPressed: conversation == null || isRunning
                      ? null
                      : widget.onClearHistory,
                  icon: const Icon(Icons.delete_outline, size: 11),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              children: [
                if (conversation == null || conversation.runs.isEmpty)
                  const _AgentEmptyState()
                else
                  ...conversation.runs.map(
                    (run) => _AgentRunCard(
                      run: run,
                      agent: widget.selectedAgent,
                      sessionId: conversation.sessionId,
                      todoTitle: todo?.title ?? 'Todo',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentRunCard extends StatelessWidget {
  const _AgentRunCard({
    required this.run,
    required this.agent,
    required this.sessionId,
    required this.todoTitle,
  });

  final AgentRun run;
  final AgentKind agent;
  final String sessionId;
  final String todoTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = run.succeeded
        ? Colors.green.shade600
        : colorScheme.error;
    final output = run.error?.trim().isNotEmpty == true
        ? run.error!.trim()
        : run.output.trim();
    final sessionLabel = sessionId.trim().isEmpty ? 'No session' : sessionId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  todoTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _InlineChip(
                label: run.succeeded ? '成功' : '失败',
                backgroundColor: statusColor.withValues(alpha: 0.1),
                foregroundColor: statusColor,
                borderColor: statusColor.withValues(alpha: 0.24),
                fontSize: 10,
                icon: run.succeeded ? Icons.check_rounded : Icons.close_rounded,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _InlineChip(
                label: agent.label,
                backgroundColor: colorScheme.surfaceContainer,
                foregroundColor: colorScheme.onSurfaceVariant,
                borderColor: colorScheme.outlineVariant,
                fontSize: 9,
                fontFamily: 'monospace',
              ),
              const SizedBox(width: 5),
              Flexible(
                child: _InlineChip(
                  label: sessionLabel,
                  backgroundColor: colorScheme.surfaceContainer,
                  foregroundColor: colorScheme.onSurfaceVariant,
                  borderColor: colorScheme.outlineVariant,
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Text(
                _formatDateTime(run.finishedAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          if (run.instruction.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              run.instruction.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
          if (output.isNotEmpty) ...[
            const SizedBox(height: 5),
            SelectableText(
              output,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgentEmptyState extends StatelessWidget {
  const _AgentEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '暂无历史记录',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _IssueImportDialog extends StatefulWidget {
  const _IssueImportDialog({required this.fetcher, required this.settings});

  final IssueFetcher fetcher;
  final IssueImportSettings settings;

  @override
  State<_IssueImportDialog> createState() => _IssueImportDialogState();
}

class _IssueImportDialogState extends State<_IssueImportDialog> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  IssueSnapshot? _issue;
  String? _error;
  bool _isFetching = false;

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchIssue() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _error = 'Issue URL is required.';
        _issue = null;
      });
      _urlFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isFetching = true;
      _error = null;
      _issue = null;
    });

    try {
      final issue = await widget.fetcher.fetch(url, widget.settings);
      if (!mounted) {
        return;
      }
      setState(() {
        _issue = issue;
        _error = null;
        _isFetching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error is IssueFetchException
            ? error.message
            : error.toString();
        _issue = null;
        _isFetching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final issue = _issue;

    return AlertDialog(
      title: const Text('Import issue'),
      content: SizedBox(
        width: 680,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    focusNode: _urlFocusNode,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    enabled: !_isFetching,
                    decoration: const InputDecoration(
                      labelText: 'Issue URL',
                      prefixIcon: Icon(Icons.link_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _fetchIssue(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _isFetching ? null : _fetchIssue,
                  icon: _isFetching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: const Text('Fetch'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(112, 56),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
            if (issue != null) ...[
              const SizedBox(height: 16),
              _DialogSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          issue.provider == IssueProvider.gitlab
                              ? Icons.account_tree_outlined
                              : Icons.code_outlined,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${issue.provider.label} · ${issue.projectPath} #${issue.number}',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      issue.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          issue.body.isEmpty ? '(No description)' : issue.body,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isFetching ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: issue == null || _isFetching
              ? null
              : () => Navigator.of(context).pop(issue),
          icon: const Icon(Icons.add_task_outlined),
          label: const Text('Add to todo'),
        ),
      ],
    );
  }
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.settings});

  final AppSettings settings;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final TextEditingController _gitlabTokenController;
  late final TextEditingController _githubTokenController;
  late bool _agentCompletionNotificationsEnabled;

  @override
  void initState() {
    super.initState();
    _gitlabTokenController = TextEditingController(
      text: widget.settings.issueImport.gitlabToken,
    );
    _githubTokenController = TextEditingController(
      text: widget.settings.issueImport.githubToken,
    );
    _agentCompletionNotificationsEnabled =
        widget.settings.agentCompletionNotificationsEnabled;
  }

  @override
  void dispose() {
    _gitlabTokenController.dispose();
    _githubTokenController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      AppSettings(
        issueImport: IssueImportSettings(
          gitlabToken: _gitlabTokenController.text.trim(),
          githubToken: _githubTokenController.text.trim(),
        ),
        agentCompletionNotificationsEnabled:
            _agentCompletionNotificationsEnabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Settings'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DialogSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.add_link_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Issue import',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _gitlabTokenController,
                    autofocus: true,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'GitLab token',
                      prefixIcon: Icon(Icons.account_tree_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _githubTokenController,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'GitHub token',
                      prefixIcon: Icon(Icons.code_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _DialogSection(
              child: Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.notifications_active_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Agent completion notifications'),
                  subtitle: const Text(
                    'Show a desktop notification when an agent finishes.',
                  ),
                  value: _agentCompletionNotificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _agentCompletionNotificationsEnabled = value;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save'),
        ),
      ],
    );
  }
}

class _ProjectDraft {
  const _ProjectDraft({required this.name, required this.folderPath});

  final String name;
  final String folderPath;
}

class _ProjectDialog extends StatefulWidget {
  const _ProjectDialog({this.project});

  final TodoProject? project;

  @override
  State<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<_ProjectDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _pathController;
  final FocusNode _nameFocusNode = FocusNode();
  String? _error;
  bool _isChecking = false;

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _pathController = TextEditingController(
      text: widget.project?.folderPath ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _chooseFolder() async {
    final path = await _pickFolderPath();
    if (path == null || path.trim().isEmpty) {
      return;
    }

    setState(() {
      _pathController.text = path;
      if (_nameController.text.trim().isEmpty) {
        _nameController.text = _folderName(path);
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final folderPath = _pathController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _error = 'Project name is required.';
      });
      _nameFocusNode.requestFocus();
      return;
    }

    if (folderPath.isEmpty) {
      setState(() {
        _error = 'Project folder is required.';
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _error = null;
    });

    final exists = await Directory(folderPath).exists();
    if (!mounted) {
      return;
    }

    if (!exists) {
      setState(() {
        _isChecking = false;
        _error = 'Folder does not exist.';
      });
      return;
    }

    Navigator.of(
      context,
    ).pop(_ProjectDraft(name: name, folderPath: folderPath));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit project' : 'Add project'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Project name',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pathController,
              decoration: InputDecoration(
                labelText: 'Folder path',
                prefixIcon: const Icon(Icons.folder_open_outlined),
                suffixIcon: IconButton(
                  tooltip: 'Choose folder',
                  onPressed: _isChecking ? null : _chooseFolder,
                  icon: const Icon(Icons.more_horiz),
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isChecking ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isChecking ? null : _save,
          icon: _isChecking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isEditing ? 'Save project' : 'Create project'),
        ),
      ],
    );
  }
}

class _EditTodoDialog extends StatefulWidget {
  const _EditTodoDialog({required this.todo});

  final TodoItem todo;

  @override
  State<_EditTodoDialog> createState() => _EditTodoDialogState();
}

class _EditTodoDialogState extends State<_EditTodoDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _detailsController;
  final FocusNode _titleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo.title);
    _detailsController = TextEditingController(text: widget.todo.details);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _titleFocusNode.requestFocus();
      return;
    }

    Navigator.of(context).pop(
      widget.todo.copyWith(
        title: title,
        details: _detailsController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit todo'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title_outlined),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _detailsController,
              minLines: 5,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Details',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter, required this.dateLabel});

  final TodoFilter filter;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final message = switch (filter) {
      TodoFilter.all => 'No tasks yet',
      TodoFilter.active => 'No open tasks',
      TodoFilter.completed => 'No completed tasks',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_rtl_outlined,
              size: 52,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              dateLabel == 'Today'
                  ? 'Add a task above to get started.'
                  : 'No matching tasks for $dateLabel.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
