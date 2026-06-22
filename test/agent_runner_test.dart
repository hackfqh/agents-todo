import 'package:agents_todos/agent_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('agent prompt asks final response to be saved verbatim', () {
    const request = AgentTaskRequest(
      agent: AgentKind.codex,
      title: 'Update agent prompt',
      details: 'Preserve the agent final response exactly.',
      instruction: 'Handle the todo.',
      conversation: null,
      workingDirectory: '/project',
      projectName: 'Todo Desk',
      projectPath: '/project',
    );

    final prompt = buildAgentPrompt(request);

    expect(
      prompt,
      contains('return your final response exactly as it should be saved'),
    );
    expect(
      prompt,
      contains('Todo Desk saves the final response exactly as returned'),
    );
    expect(prompt, isNot(contains('return a concise result')));
  });

  test('extracts session ids from agent JSON output', () {
    expect(
      extractSessionIdFromOutput('{"session_id":"session_123"}'),
      'session_123',
    );
  });

  test('extracts Codex thread ids from agent JSON output', () {
    const rawOutput = '''
{"type":"thread/started","thread_id":"thread_direct_123"}
{"type":"message","message":"done"}
''';

    expect(extractSessionIdFromOutput(rawOutput), 'thread_direct_123');
  });

  test('extracts nested Codex thread ids from agent JSON output', () {
    const rawOutput =
        '{"method":"thread/started","params":{"thread":{"id":"thread_nested_123"}}}';

    expect(extractSessionIdFromOutput(rawOutput), 'thread_nested_123');
  });
}
