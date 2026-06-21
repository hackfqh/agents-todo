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

    expect(find.text('Todo Desk'), findsOneWidget);
    expect(find.text('No tasks yet'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '新增任务，按 Enter 确认...'),
      'Review desktop build',
    );
    await tester.tap(find.byIcon(Icons.add_rounded));
    await _pumpUi(tester);

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

    expect(find.text('High priority'), findsOneWidget);
    expect(find.text('Medium priority'), findsOneWidget);
    expect(find.text('Low priority'), findsOneWidget);

    final dragStart = tester.getCenter(find.byTooltip('Move priority'));
    final dragEnd = tester.getCenter(find.text('High priority'));
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

    await tester.enterText(
      find.widgetWithText(TextField, '新增任务，按 Enter 确认...'),
      'Silent agent',
    );
    await tester.tap(find.byIcon(Icons.add_rounded));
    await _pumpUi(tester);

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

    await tester.enterText(
      find.widgetWithText(TextField, '新增任务，按 Enter 确认...'),
      'Ask agent',
    );
    await tester.tap(find.byIcon(Icons.add_rounded));
    await _pumpUi(tester);

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

    await tester.enterText(
      find.widgetWithText(TextField, '新增任务，按 Enter 确认...'),
      'Fix failure',
    );
    await tester.tap(find.byIcon(Icons.add_rounded));
    await _pumpUi(tester);

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

class _FakeRunner implements AgentTaskRunner {
  _FakeRunner({this.error, this.exitCode = 0});

  final List<AgentTaskRequest> requests = <AgentTaskRequest>[];
  final String? error;
  final int exitCode;

  @override
  Future<AgentTaskResult> run(AgentTaskRequest request) async {
    requests.add(request);
    return AgentTaskResult(
      sessionId: request.conversation?.sessionId ?? 'test-session-1',
      output: 'Fake result for ${request.title}',
      error: error,
      exitCode: exitCode,
      rawOutput: '{}',
    );
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
