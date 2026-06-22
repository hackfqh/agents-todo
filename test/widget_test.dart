import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agents_todos/agent_runner.dart';
import 'package:agents_todos/main.dart';

void main() {
  test('migrates legacy issue settings into app settings', () {
    final data = TodoData.fromJson({
      'selectedProjectId': 'project-1',
      'projects': [
        {
          'id': 'project-1',
          'name': 'Legacy Project',
          'folderPath': '/tmp',
          'todos': [],
        },
      ],
      'issueSettings': {
        'gitlabToken': 'legacy-gitlab-token',
        'githubToken': 'legacy-github-token',
      },
    });

    expect(data.settings.issueImport.gitlabToken, 'legacy-gitlab-token');
    expect(data.settings.issueImport.githubToken, 'legacy-github-token');
    expect(data.settings.agentCompletionNotificationsEnabled, isTrue);
  });

  testWidgets('can add, edit details, and remove a todo', (
    WidgetTester tester,
  ) async {
    _setDesktopSize(tester);
    final store = MemoryTodoStore();

    await tester.pumpWidget(TodoApp(store: store, agentRunner: _FakeRunner()));
    await _pumpUi(tester);

    expect(find.byKey(const ValueKey('quick-add-button')), findsOneWidget);
    expect(find.text('Todo Desk'), findsNothing);
    expect(find.text('No tasks yet'), findsOneWidget);

    await _addTodoThroughDialog(tester, title: 'Review desktop build');

    expect(find.text('Review desktop build'), findsAtLeastNWidgets(1));
    expect(find.text('No tasks yet'), findsNothing);

    await tester.tap(find.byTooltip('Edit todo'));
    await _pumpUi(tester);

    expect(find.text('Edit todo'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Details'),
      'Check macOS build and keep Windows notes ready.',
    );
    await tester.tap(find.text('Save'));
    await _pumpUi(tester);

    expect(
      find.text('Check macOS build and keep Windows notes ready.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Delete todo'));
    await _pumpUi(tester);

    expect(find.text('Review desktop build'), findsNothing);
    expect(find.text('No tasks yet'), findsOneWidget);
  });

  testWidgets('top bar keeps add action left and tools right', (
    WidgetTester tester,
  ) async {
    _setDesktopSize(tester);
    final store = MemoryTodoStore();

    await tester.pumpWidget(TodoApp(store: store, agentRunner: _FakeRunner()));
    await _pumpUi(tester);

    expect(find.text('Todo Desk'), findsNothing);

    final addRect = tester.getRect(
      find.byKey(const ValueKey('quick-add-button')),
    );
    final settingsRect = tester.getRect(find.byTooltip('Settings'));
    final importRect = tester.getRect(find.byTooltip('Import issue'));

    expect(addRect.left, lessThan(24));
    expect(settingsRect.left, greaterThan(addRect.right));
    expect(importRect.right, greaterThan(1200));
  });

  testWidgets(
    'todo session chips show agent labels and jump to matching conversation',
    (WidgetTester tester) async {
      _setDesktopSize(tester);
      final store = MemoryTodoStore(
        TodoData(
          projects: [
            TodoProject(
              id: 'project-1',
              name: 'Agent Project',
              folderPath: '/tmp',
              todos: [
                TodoItem(
                  id: 'todo-1',
                  title: 'Coordinate follow-up',
                  details: 'Check how the next pass should continue.',
                  createdAt: DateTime(2026, 6, 22),
                  priority: TodoPriority.medium,
                  completed: false,
                  conversations: {
                    AgentKind.codex: AgentConversation(
                      agent: AgentKind.codex,
                      sessionId: 'codex-session-1',
                      updatedAt: DateTime(2026, 6, 21, 10),
                      runs: const [],
                    ),
                    AgentKind.claudeCode: AgentConversation(
                      agent: AgentKind.claudeCode,
                      sessionId: 'claude-session-1',
                      updatedAt: DateTime(2026, 6, 22, 9),
                      runs: const [],
                    ),
                  },
                ),
              ],
            ),
          ],
          selectedProjectId: 'project-1',
        ),
      );

      await tester.pumpWidget(
        TodoApp(store: store, agentRunner: _FakeRunner()),
      );
      await _pumpUi(tester);

      expect(find.text('Codex · codex-session-1'), findsOneWidget);
      expect(find.text('Claude Code · claude-session-1'), findsOneWidget);

      await tester.tap(find.text('Claude Code · claude-session-1'));
      await _pumpUi(tester);

      final sessionField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Session ID'),
      );
      expect(sessionField.controller?.text, 'claude-session-1');
    },
  );

  testWidgets('multi-turn agent history shows latest messages first', (
    WidgetTester tester,
  ) async {
    _setDesktopSize(tester);
    final store = MemoryTodoStore(
      TodoData(
        projects: [
          TodoProject(
            id: 'project-1',
            name: 'History Project',
            folderPath: '/tmp',
            todos: [
              TodoItem(
                id: 'todo-1',
                title: 'Trace conversation history',
                details: 'Show the latest turns at the top of the right panel.',
                createdAt: DateTime(2026, 6, 22),
                priority: TodoPriority.medium,
                completed: false,
                conversations: {
                  AgentKind.codex: AgentConversation(
                    agent: AgentKind.codex,
                    sessionId: 'codex-history-1',
                    updatedAt: DateTime(2026, 6, 22, 11),
                    runs: [
                      AgentRun(
                        id: 'run-2',
                        agentId: AgentKind.codex.id,
                        instruction: 'Follow up turn',
                        output: 'Second agent reply',
                        error: null,
                        exitCode: 0,
                        startedAt: DateTime(2026, 6, 22, 11, 10),
                        finishedAt: DateTime(2026, 6, 22, 11, 12),
                      ),
                      AgentRun(
                        id: 'run-1',
                        agentId: AgentKind.codex.id,
                        instruction: 'Initial turn',
                        output: 'First agent reply',
                        error: null,
                        exitCode: 0,
                        startedAt: DateTime(2026, 6, 22, 10, 40),
                        finishedAt: DateTime(2026, 6, 22, 10, 42),
                      ),
                    ],
                  ),
                },
              ),
            ],
          ),
        ],
        selectedProjectId: 'project-1',
      ),
    );

    await tester.pumpWidget(TodoApp(store: store, agentRunner: _FakeRunner()));
    await _pumpUi(tester);
    await tester.tap(find.text('Trace conversation history'));
    await _pumpUi(tester);

    expect(find.text('Initial turn'), findsOneWidget);
    expect(find.text('First agent reply'), findsOneWidget);
    expect(find.text('Follow up turn'), findsOneWidget);
    expect(find.text('Second agent reply'), findsOneWidget);

    expect(
      tester.getTopLeft(find.text('Follow up turn')).dy,
      lessThan(tester.getTopLeft(find.text('Initial turn')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Second agent reply')).dy,
      lessThan(tester.getTopLeft(find.text('First agent reply')).dy),
    );
  });

  testWidgets(
    'agent instruction clears after send and resets for new context',
    (WidgetTester tester) async {
      _setDesktopSize(tester);
      final store = MemoryTodoStore();
      final runner = _FakeRunner();

      await tester.pumpWidget(TodoApp(store: store, agentRunner: runner));
      await _pumpUi(tester);

      await _addTodoThroughDialog(tester, title: 'First agent task');
      await tester.enterText(
        find.widgetWithText(TextField, 'Instruction'),
        'Run the first pass',
      );
      await tester.tap(find.text('Send to agent'));
      await _pumpUi(tester);

      expect(runner.requests.single.instruction, 'Run the first pass');
      expect(_agentInstructionText(tester), isEmpty);

      await _addTodoThroughDialog(tester, title: 'Second agent task');
      expect(
        _agentInstructionText(tester),
        'Please handle this todo and report the result.',
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Instruction'),
        'Draft a new session prompt',
      );
      await tester.tap(find.text('新会话'));
      await _pumpUi(tester);

      expect(
        _agentInstructionText(tester),
        'Please handle this todo and report the result.',
      );
    },
  );

  testWidgets('send continues existing agent session by default', (
    WidgetTester tester,
  ) async {
    _setDesktopSize(tester);
    final store = MemoryTodoStore();
    final runner = _FakeRunner();

    await tester.pumpWidget(TodoApp(store: store, agentRunner: runner));
    await _pumpUi(tester);

    await _addTodoThroughDialog(tester, title: 'Keep one Codex thread');

    await tester.enterText(
      find.widgetWithText(TextField, 'Instruction'),
      'First turn',
    );
    await tester.tap(find.text('Send to agent'));
    await _pumpUi(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Instruction'),
      'Second turn',
    );
    await tester.tap(find.text('Send to agent'));
    await _pumpUi(tester);

    expect(runner.requests, hasLength(2));
    expect(runner.requests.first.conversation, isNull);
    expect(runner.requests.last.conversation?.sessionId, 'test-session-1');

    final savedTodo = (await store.load()).projects.first.todos.first;
    final conversation = savedTodo.conversations[AgentKind.codex];
    expect(conversation?.runs.map((run) => run.instruction), [
      'Second turn',
      'First turn',
    ]);
    expect(find.text('Second turn'), findsOneWidget);
    expect(find.text('First turn'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Second turn')).dy,
      lessThan(tester.getTopLeft(find.text('First turn')).dy),
    );
  });

  testWidgets('new conversation button makes the next send start fresh', (
    WidgetTester tester,
  ) async {
    _setDesktopSize(tester);
    final store = MemoryTodoStore();
    final runner = _FakeRunner();

    await tester.pumpWidget(TodoApp(store: store, agentRunner: runner));
    await _pumpUi(tester);

    await _addTodoThroughDialog(tester, title: 'Split Codex threads');

    await tester.enterText(
      find.widgetWithText(TextField, 'Instruction'),
      'First thread',
    );
    await tester.tap(find.text('Send to agent'));
    await _pumpUi(tester);

    await tester.tap(find.text('新会话'));
    await _pumpUi(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Instruction'),
      'Fresh thread',
    );
    await tester.tap(find.text('Send to agent'));
    await _pumpUi(tester);

    expect(runner.requests, hasLength(2));
    expect(runner.requests.first.conversation, isNull);
    expect(runner.requests.last.conversation, isNull);

    final savedTodo = (await store.load()).projects.first.todos.first;
    final conversation = savedTodo.conversations[AgentKind.codex];
    expect(conversation?.sessionId, 'test-session-2');
    expect(conversation?.runs.map((run) => run.instruction), ['Fresh thread']);
  });

  testWidgets('add button opens dialog and saves title priority and date', (
    WidgetTester tester,
  ) async {
    _setDesktopSize(tester);
    final store = MemoryTodoStore();

    await tester.pumpWidget(TodoApp(store: store, agentRunner: _FakeRunner()));
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('quick-add-button')));
    await _pumpUi(tester);

    expect(find.text('新增待办'), findsOneWidget);
    expect(find.widgetWithText(TextField, '待办名称'), findsOneWidget);
    expect(find.widgetWithText(TextField, '待办详情（选填）'), findsOneWidget);
    expect(find.text('中优先级'), findsOneWidget);
    expect(find.byKey(const ValueKey('todo-date-button')), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '待办名称'), '写周报');
    await tester.enterText(
      find.widgetWithText(TextField, '待办详情（选填）'),
      '整理本周进展和风险。',
    );
    await tester.tap(find.text('中优先级'));
    await _pumpUi(tester);
    expect(find.text('高优先级'), findsOneWidget);
    expect(find.text('低优先级'), findsOneWidget);
    await tester.tap(find.text('低优先级').last);
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('todo-date-button')));
    await _pumpUi(tester);
    await tester.tap(find.text('15').last);
    await _pumpUi(tester);
    await tester.tap(find.text('OK'));
    await _pumpUi(tester);
    await tester.tap(find.text('创建待办'));
    await _pumpUi(tester);

    final savedTodo = (await store.load()).projects.first.todos.first;
    expect(savedTodo.title, '写周报');
    expect(savedTodo.details, '整理本周进展和风险。');
    expect(savedTodo.priority, TodoPriority.low);
    expect(savedTodo.createdAt.day, 15);
  });

  testWidgets('shows all dates by default and can filter today todos', (
    WidgetTester tester,
  ) async {
    _setDesktopSize(tester);
    final now = DateTime.now();
    final store = MemoryTodoStore(
      TodoData(
        selectedProjectId: 'project-1',
        projects: [
          TodoProject(
            id: 'project-1',
            name: 'Date Project',
            folderPath: 'test-folder',
            todos: [
              TodoItem(
                id: 'old',
                title: 'Yesterday task',
                details: '',
                createdAt: now.subtract(const Duration(days: 1)),
                completed: false,
                conversations: const {},
              ),
              TodoItem(
                id: 'today',
                title: 'Today task',
                details: '',
                createdAt: now,
                completed: false,
                conversations: const {},
              ),
            ],
          ),
        ],
      ),
    );

    await tester.pumpWidget(TodoApp(store: store, agentRunner: _FakeRunner()));
    await _pumpUi(tester);

    expect(find.text('Today task'), findsAtLeastNWidgets(1));
    expect(find.text('Yesterday task'), findsAtLeastNWidgets(1));

    await tester.tap(find.byIcon(Icons.today_outlined));
    await _pumpUi(tester);

    expect(find.text('Today task'), findsAtLeastNWidgets(1));
    expect(find.text('Yesterday task'), findsNothing);
  });

  testWidgets('can move a todo between priority sections', (
    WidgetTester tester,
  ) async {
    _setDesktopSize(tester);
    final store = MemoryTodoStore(
      TodoData(
        selectedProjectId: 'project-1',
        projects: [
          TodoProject(
            id: 'project-1',
            name: 'Priority Project',
            folderPath: 'test-folder',
            todos: [
              TodoItem(
                id: 'priority-todo',
                title: 'Prioritize agent handoff',
                details: '',
                createdAt: DateTime.now(),
                completed: false,
                conversations: const {},
              ),
            ],
          ),
        ],
      ),
    );

    await tester.pumpWidget(TodoApp(store: store, agentRunner: _FakeRunner()));
    await _pumpUi(tester);

    expect(find.text('高优先级'), findsOneWidget);
    expect(find.text('中优先级'), findsOneWidget);
    expect(find.text('低优先级'), findsOneWidget);

    final dragStart = tester.getCenter(find.byTooltip('Move priority'));
    final dragEnd = tester.getCenter(find.text('高优先级'));
    final gesture = await tester.startGesture(dragStart);
    await tester.pump();
    await gesture.moveTo(dragEnd);
    await tester.pump();
    await gesture.up();
    await _pumpUi(tester);

    final savedData = await store.load();
    expect(savedData.projects.first.todos.first.priority, TodoPriority.high);
  });

  testWidgets('can configure issue token and import an issue as a todo', (
    WidgetTester tester,
  ) async {
    _setDesktopSize(tester);
    final store = MemoryTodoStore();
    final issueFetcher = _FakeIssueFetcher(
      const IssueSnapshot(
        provider: IssueProvider.gitlab,
        url: 'https://gitpd.paodingai.com/group/repo/-/issues/20',
        title: 'Fix import parsing',
        body: 'The parser should preserve JSON-only output.',
        projectPath: 'group/repo',
        number: 20,
      ),
    );

    await tester.pumpWidget(
      TodoApp(
        store: store,
        agentRunner: _FakeRunner(),
        issueFetcher: issueFetcher,
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Settings'));
    await _pumpUi(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Issue import'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'GitLab token'),
      'glpat-test-token',
    );
    await tester.tap(find.text('Save'));
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Import issue'));
    await _pumpUi(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Issue URL'),
      'https://gitpd.paodingai.com/group/repo/-/issues/20',
    );
    await tester.tap(find.text('Fetch'));
    await _pumpUi(tester);

    expect(find.text('Fix import parsing'), findsOneWidget);
    expect(
      find.text('The parser should preserve JSON-only output.'),
      findsOneWidget,
    );
    expect(issueFetcher.lastSettings?.gitlabToken, 'glpat-test-token');

    await tester.tap(find.text('Add to todo'));
    await _pumpUi(tester);

    final savedData = await store.load();
    expect(savedData.issueSettings.gitlabToken, 'glpat-test-token');
    expect(savedData.projects.first.todos.first.title, 'Fix import parsing');
    expect(
      savedData.projects.first.todos.first.details,
      contains('The parser should preserve JSON-only output.'),
    );
    expect(savedData.settings.agentCompletionNotificationsEnabled, isTrue);
  });

  testWidgets('can disable agent completion notifications in settings', (
    WidgetTester tester,
  ) async {
    _setDesktopSize(tester);
    final store = MemoryTodoStore();
    final notifications = _FakeNotificationService();

    await tester.pumpWidget(
      TodoApp(
        store: store,
        agentRunner: _FakeRunner(),
        notificationService: notifications,
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Settings'));
    await _pumpUi(tester);
    expect(find.text('Agent completion notifications'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.tap(find.text('Save'));
    await _pumpUi(tester);

    final savedSettings = await store.load();
    expect(savedSettings.settings.agentCompletionNotificationsEnabled, isFalse);

    await _addTodoThroughDialog(tester, title: 'Silent agent');

    await tester.tap(find.text('Send to agent'));
    await _pumpUi(tester);

    expect(notifications.calls, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('agent completion triggers desktop notification', (
    WidgetTester tester,
  ) async {
    _setDesktopSize(tester);
    final store = MemoryTodoStore();
    final notifications = _FakeNotificationService();

    await tester.pumpWidget(
      TodoApp(
        store: store,
        agentRunner: _FakeRunner(),
        notificationService: notifications,
      ),
    );
    await _pumpUi(tester);

    await _addTodoThroughDialog(tester, title: 'Ask agent');

    final settingsButton = find.byTooltip('Settings');
    final importButton = find.byTooltip('Import issue');
    final settingsRect = tester.getRect(settingsButton);
    final importRect = tester.getRect(importButton);

    await tester.enterText(
      find.widgetWithText(TextField, 'Instruction'),
      'Run the task',
    );
    await tester.tap(find.text('Send to agent'));
    await _pumpUi(tester);

    expect(notifications.calls, hasLength(1));
    expect(notifications.calls.single.title, 'Codex completed a todo');
    expect(
      notifications.calls.single.body,
      '"Ask agent" finished successfully. Result saved in Todo Desk.',
    );
    expect(notifications.calls.single.isError, isFalse);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.getRect(settingsButton), settingsRect);
    expect(tester.getRect(importButton), importRect);
  });

  testWidgets('agent failure uses attention desktop notification copy', (
    WidgetTester tester,
  ) async {
    _setDesktopSize(tester);
    final store = MemoryTodoStore();
    final notifications = _FakeNotificationService();

    await tester.pumpWidget(
      TodoApp(
        store: store,
        agentRunner: _FakeRunner(error: 'Agent failed.', exitCode: 1),
        notificationService: notifications,
      ),
    );
    await _pumpUi(tester);

    await _addTodoThroughDialog(tester, title: 'Fix failure');

    await tester.tap(find.text('Send to agent'));
    await _pumpUi(tester);

    expect(notifications.calls, hasLength(1));
    expect(notifications.calls.single.title, 'Codex needs attention');
    expect(
      notifications.calls.single.body,
      '"Fix failure" returned an error. Open Todo Desk to review the run.',
    );
    expect(notifications.calls.single.isError, isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });
}

void _setDesktopSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

String _agentInstructionText(WidgetTester tester) {
  final instructionField = tester.widget<TextField>(
    find.widgetWithText(TextField, 'Instruction'),
  );
  return instructionField.controller?.text ?? '';
}

Future<void> _addTodoThroughDialog(
  WidgetTester tester, {
  required String title,
  String details = '',
}) async {
  await tester.tap(find.byKey(const ValueKey('quick-add-button')));
  await _pumpUi(tester);
  await tester.enterText(find.widgetWithText(TextField, '待办名称'), title);
  if (details.isNotEmpty) {
    await tester.enterText(find.widgetWithText(TextField, '待办详情（选填）'), details);
  }
  await tester.tap(find.text('创建待办'));
  await _pumpUi(tester);
}

class _FakeRunner implements AgentTaskRunner {
  _FakeRunner({this.error, this.exitCode = 0});

  final List<AgentTaskRequest> requests = <AgentTaskRequest>[];
  final String? error;
  final int exitCode;
  int _sessionCount = 0;

  @override
  Future<AgentTaskResult> run(AgentTaskRequest request) async {
    requests.add(request);
    final sessionId = request.conversation?.sessionId ?? _nextSessionId();
    return AgentTaskResult(
      sessionId: sessionId,
      output: 'Fake result for ${request.title}',
      error: error,
      exitCode: exitCode,
      rawOutput: '{}',
    );
  }

  String _nextSessionId() {
    _sessionCount += 1;
    return 'test-session-$_sessionCount';
  }
}

class _FakeNotificationCall {
  const _FakeNotificationCall({
    required this.title,
    required this.body,
    required this.isError,
  });

  final String title;
  final String body;
  final bool isError;
}

class _FakeNotificationService implements DesktopNotificationService {
  final List<_FakeNotificationCall> calls = <_FakeNotificationCall>[];

  @override
  Future<bool> show({
    required String title,
    required String body,
    required bool isError,
  }) async {
    calls.add(
      _FakeNotificationCall(title: title, body: body, isError: isError),
    );
    return true;
  }
}

class _FakeIssueFetcher implements IssueFetcher {
  _FakeIssueFetcher(this.issue);

  final IssueSnapshot issue;
  IssueImportSettings? lastSettings;
  String? lastUrl;

  @override
  Future<IssueSnapshot> fetch(String url, IssueImportSettings settings) async {
    lastUrl = url;
    lastSettings = settings;
    return issue;
  }
}
