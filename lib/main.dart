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

class TodoApp extends StatelessWidget {
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

  ThemeData _lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F7F8),
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Todo Desk',
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      themeMode: ThemeMode.system,
      home: TodoHomePage(
        store: store,
        agentRunner: agentRunner,
        issueFetcher: issueFetcher,
        notificationService: notificationService,
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
      TodoPriority.low => colorScheme.primary,
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
  });

  final TodoStore store;
  final AgentTaskRunner agentRunner;
  final IssueFetcher issueFetcher;
  final DesktopNotificationService notificationService;

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<TodoProject> _projects = <TodoProject>[];
  String? _selectedProjectId;
  TodoFilter _filter = TodoFilter.all;
  DateFilterMode _dateFilterMode = DateFilterMode.today;
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
        _selectFirstVisibleTodoIfNeeded();
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

    _insertTodo(_createTodo(title: title, details: ''));
    _controller.clear();
    _inputFocusNode.requestFocus();
  }

  TodoItem _createTodo({required String title, required String details}) {
    final now = DateTime.now();
    return TodoItem(
      id: now.microsecondsSinceEpoch.toString(),
      title: title,
      details: details,
      createdAt: now,
      priority: TodoPriority.medium,
      completed: false,
      conversations: {},
    );
  }

  void _insertTodo(TodoItem todo) {
    setState(() {
      _replaceSelectedProjectTodos(<TodoItem>[todo, ..._todos]);
      _selectedTodoId = todo.id;
      _filter = TodoFilter.all;
      _dateFilterMode = DateFilterMode.today;
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
      _dateFilterMode = DateFilterMode.today;
      _selectedDate = _today();
      _rangeStart = _today();
      _rangeEnd = _today();
      _selectFirstVisibleTodoIfNeeded();
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
      _selectFirstVisibleTodoIfNeeded();
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
      _selectFirstVisibleTodoIfNeeded();
    });

    unawaited(_persistTodos());
  }

  void _clearCompleted() {
    if (_completedCount == 0) {
      return;
    }

    setState(() {
      final updatedTodos = _todos
          .where((item) => !(item.completed && _matchesDateFilter(item)))
          .toList();
      _replaceSelectedProjectTodos(updatedTodos);
      _selectFirstVisibleTodoIfNeeded();
    });

    unawaited(_persistTodos());
  }

  void _setDateFilterMode(DateFilterMode mode) {
    setState(() {
      _dateFilterMode = mode;
      if (mode == DateFilterMode.today) {
        _selectedDate = _today();
      }
      _selectFirstVisibleTodoIfNeeded();
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
      _selectFirstVisibleTodoIfNeeded();
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
      _selectFirstVisibleTodoIfNeeded();
    });
  }

  Future<void> _sendToAgent(TodoItem todo, String instruction) async {
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
        conversation: todo.conversations[agent],
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
          final sessionId = result.sessionId ?? existing?.sessionId ?? '';
          final updatedConversation = AgentConversation(
            agent: agent,
            sessionId: sessionId,
            updatedAt: finishedAt,
            runs: <AgentRun>[run, ...?existing?.runs],
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

  String get _dateFilterLabel {
    switch (_dateFilterMode) {
      case DateFilterMode.today:
        return 'Today';
      case DateFilterMode.day:
        return _formatDate(_selectedDate);
      case DateFilterMode.range:
        return '${_formatDate(_rangeStart)} to ${_formatDate(_rangeEnd)}';
      case DateFilterMode.all:
        return 'All dates';
    }
  }

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

  void _selectFirstVisibleTodoIfNeeded() {
    final selectedTodoId = _selectedTodoId;
    final visibleTodos = _visibleTodos;
    if (selectedTodoId != null &&
        visibleTodos.any((item) => item.id == selectedTodoId)) {
      return;
    }
    _selectedTodoId = visibleTodos.isEmpty ? null : visibleTodos.first.id;
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleTodos = _visibleTodos;
    final selectedTodo = _selectedTodo;
    final selectedProject = _selectedProject;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Todo Desk',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${selectedProject?.name ?? 'No project'} · $_dateFilterLabel · $_openCount open · $_completedCount done',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              IconButton.outlined(
                                tooltip: 'Import issue',
                                onPressed: _isLoading || selectedProject == null
                                    ? null
                                    : _openIssueImporter,
                                icon: const Icon(Icons.add_link_outlined),
                              ),
                              IconButton.outlined(
                                tooltip: 'Settings',
                                onPressed: _isLoading ? null : _openSettings,
                                icon: const Icon(Icons.settings_outlined),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_notice != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _notice!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _ProjectBar(
                    projects: _projects,
                    selectedProject: selectedProject,
                    isLoading: _isLoading,
                    onProjectSelected: _selectProject,
                    onAddProject: _addProject,
                    onEditProject: selectedProject == null
                        ? null
                        : () => _editProject(selectedProject),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 620;
                      final textField = TextField(
                        controller: _controller,
                        focusNode: _inputFocusNode,
                        enabled: !_isLoading && selectedProject != null,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addTodo(),
                        decoration: const InputDecoration(
                          labelText: 'New task',
                          prefixIcon: Icon(Icons.edit_note_outlined),
                          border: OutlineInputBorder(),
                        ),
                      );

                      final addButton = FilledButton.icon(
                        onPressed: _isLoading || selectedProject == null
                            ? null
                            : _addTodo,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(120, 56),
                        ),
                      );

                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            textField,
                            const SizedBox(height: 12),
                            addButton,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: textField),
                          const SizedBox(width: 12),
                          addButton,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 12,
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _DateFilterControl(
                        mode: _dateFilterMode,
                        selectedDate: _selectedDate,
                        rangeStart: _rangeStart,
                        rangeEnd: _rangeEnd,
                        onModeChanged: _setDateFilterMode,
                        onPickSingleDate: _pickSingleDate,
                        onPickDateRange: _pickDateRange,
                      ),
                      SegmentedButton<TodoFilter>(
                        segments: const [
                          ButtonSegment<TodoFilter>(
                            value: TodoFilter.all,
                            label: Text('All'),
                            icon: Icon(Icons.list_alt_outlined),
                          ),
                          ButtonSegment<TodoFilter>(
                            value: TodoFilter.active,
                            label: Text('Open'),
                            icon: Icon(Icons.radio_button_unchecked_outlined),
                          ),
                          ButtonSegment<TodoFilter>(
                            value: TodoFilter.completed,
                            label: Text('Done'),
                            icon: Icon(Icons.check_circle_outline),
                          ),
                        ],
                        selected: <TodoFilter>{_filter},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _filter = selection.first;
                            _selectFirstVisibleTodoIfNeeded();
                          });
                        },
                      ),
                      if (_completedCount > 0)
                        TextButton.icon(
                          onPressed: _clearCompleted,
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: const Text('Clear completed'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final todoList = _TodoListPanel(
                          isLoading: _isLoading,
                          visibleTodos: visibleTodos,
                          selectedTodoId: _selectedTodoId,
                          filter: _filter,
                          dateLabel: _dateFilterLabel,
                          scrollController: _scrollController,
                          onSelectTodo: (todo) {
                            setState(() {
                              _selectedTodoId = todo.id;
                            });
                          },
                          onToggleTodo: _toggleTodo,
                          onPriorityChanged: _changeTodoPriority,
                          onEditTodo: _editTodo,
                          onDeleteTodo: _deleteTodo,
                        );
                        final agentPanel = _AgentPanel(
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
                              : (instruction) =>
                                    _sendToAgent(selectedTodo, instruction),
                        );

                        if (constraints.maxWidth < 900) {
                          return Column(
                            children: [
                              Expanded(flex: 5, child: todoList),
                              const SizedBox(height: 16),
                              Expanded(flex: 4, child: agentPanel),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(flex: 6, child: todoList),
                            const SizedBox(width: 16),
                            Expanded(flex: 5, child: agentPanel),
                          ],
                        );
                      },
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

class _ProjectBar extends StatelessWidget {
  const _ProjectBar({
    required this.projects,
    required this.selectedProject,
    required this.isLoading,
    required this.onProjectSelected,
    required this.onAddProject,
    required this.onEditProject,
  });

  final List<TodoProject> projects;
  final TodoProject? selectedProject;
  final bool isLoading;
  final ValueChanged<String> onProjectSelected;
  final VoidCallback onAddProject;
  final VoidCallback? onEditProject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final projectPicker = DropdownButtonFormField<String>(
              initialValue: selectedProject?.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Project',
                prefixIcon: Icon(Icons.folder_outlined),
                border: OutlineInputBorder(),
              ),
              items: projects.map((project) {
                return DropdownMenuItem<String>(
                  value: project.id,
                  child: Text(project.name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        onProjectSelected(value);
                      }
                    },
            );

            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isLoading ? null : onAddProject,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('Add project'),
                ),
                IconButton.outlined(
                  tooltip: 'Edit project',
                  onPressed: isLoading ? null : onEditProject,
                  icon: const Icon(Icons.drive_file_rename_outline),
                ),
              ],
            );

            final path = selectedProject?.folderPath ?? '';
            final details = Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText(
                path.isEmpty ? 'No project folder selected.' : path,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );

            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  projectPicker,
                  const SizedBox(height: 10),
                  actions,
                  details,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: projectPicker),
                    const SizedBox(width: 12),
                    actions,
                  ],
                ),
                details,
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
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<DateFilterMode>(
          segments: const [
            ButtonSegment<DateFilterMode>(
              value: DateFilterMode.today,
              label: Text('Today'),
              icon: Icon(Icons.today_outlined),
            ),
            ButtonSegment<DateFilterMode>(
              value: DateFilterMode.day,
              label: Text('Date'),
              icon: Icon(Icons.calendar_month_outlined),
            ),
            ButtonSegment<DateFilterMode>(
              value: DateFilterMode.range,
              label: Text('Range'),
              icon: Icon(Icons.date_range_outlined),
            ),
            ButtonSegment<DateFilterMode>(
              value: DateFilterMode.all,
              label: Text('All'),
              icon: Icon(Icons.event_available_outlined),
            ),
          ],
          selected: <DateFilterMode>{mode},
          onSelectionChanged: (selection) => onModeChanged(selection.first),
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

class _TodoListPanel extends StatelessWidget {
  const _TodoListPanel({
    required this.isLoading,
    required this.visibleTodos,
    required this.selectedTodoId,
    required this.filter,
    required this.dateLabel,
    required this.scrollController,
    required this.onSelectTodo,
    required this.onToggleTodo,
    required this.onPriorityChanged,
    required this.onEditTodo,
    required this.onDeleteTodo,
  });

  final bool isLoading;
  final List<TodoItem> visibleTodos;
  final String? selectedTodoId;
  final TodoFilter filter;
  final String dateLabel;
  final ScrollController scrollController;
  final ValueChanged<TodoItem> onSelectTodo;
  final void Function(TodoItem todo, bool? completed) onToggleTodo;
  final void Function(TodoItem todo, TodoPriority priority) onPriorityChanged;
  final ValueChanged<TodoItem> onEditTodo;
  final ValueChanged<TodoItem> onDeleteTodo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : visibleTodos.isEmpty
          ? _EmptyState(filter: filter, dateLabel: dateLabel)
          : Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(10),
                children: TodoPriority.values.map((priority) {
                  final priorityTodos = visibleTodos
                      .where((todo) => todo.priority == priority)
                      .toList();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TodoPrioritySection(
                      priority: priority,
                      todos: priorityTodos,
                      selectedTodoId: selectedTodoId,
                      onSelectTodo: onSelectTodo,
                      onToggleTodo: onToggleTodo,
                      onPriorityChanged: onPriorityChanged,
                      onEditTodo: onEditTodo,
                      onDeleteTodo: onDeleteTodo,
                    ),
                  );
                }).toList(),
              ),
            ),
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isTargeted
                ? priorityColor.withValues(alpha: 0.10)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.26),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isTargeted
                  ? priorityColor
                  : colorScheme.outlineVariant.withValues(alpha: 0.76),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(priority.icon, size: 18, color: priorityColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${priority.label} priority',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    todos.length.toString(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (todos.isEmpty)
                Container(
                  constraints: const BoxConstraints(minHeight: 54),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.64),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Text(
                    'No ${priority.label.toLowerCase()} priority tasks',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Column(
                  children: todos.asMap().entries.map((entry) {
                    return Padding(
                      padding: EdgeInsets.only(top: entry.key == 0 ? 0 : 8),
                      child: _TodoTile(
                        todo: entry.value,
                        isSelected: entry.value.id == selectedTodoId,
                        onSelectTodo: onSelectTodo,
                        onToggleTodo: onToggleTodo,
                        onEditTodo: onEditTodo,
                        onDeleteTodo: onDeleteTodo,
                      ),
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

class _TodoTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = todo.completed;
    final agentCount = todo.conversations.length;

    return Material(
      color: isSelected
          ? colorScheme.secondaryContainer.withValues(alpha: 0.55)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelectTodo(todo),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Draggable<TodoItem>(
                data: todo,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: _TodoDragPreview(todo: todo),
                childWhenDragging: Opacity(
                  opacity: 0.35,
                  child: _DragHandle(color: colorScheme.onSurfaceVariant),
                ),
                child: _DragHandle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 2),
              Checkbox(
                value: isCompleted,
                onChanged: (value) => onToggleTodo(todo, value),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: isCompleted
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                        ),
                      ),
                      if (todo.details.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          todo.details.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Text(
                        'Added ${_formatDate(todo.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (agentCount > 0) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: todo.conversations.values.map((
                            conversation,
                          ) {
                            return Chip(
                              avatar: const Icon(
                                Icons.smart_toy_outlined,
                                size: 16,
                              ),
                              label: Text(conversation.agent.label),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit todo',
                onPressed: () => onEditTodo(todo),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete todo',
                onPressed: () => onDeleteTodo(todo),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Move priority',
      child: SizedBox(
        width: 28,
        height: 44,
        child: Icon(Icons.drag_indicator_rounded, color: color),
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
      elevation: 10,
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: todo.priority.color(colorScheme)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              todo.priority.icon,
              size: 18,
              color: todo.priority.color(colorScheme),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                todo.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentPanel extends StatefulWidget {
  const _AgentPanel({
    required this.todo,
    required this.selectedAgent,
    required this.runningAgent,
    required this.onAgentChanged,
    required this.onRun,
  });

  final TodoItem? todo;
  final AgentKind selectedAgent;
  final AgentKind? runningAgent;
  final ValueChanged<AgentKind> onAgentChanged;
  final Future<void> Function(String instruction)? onRun;

  @override
  State<_AgentPanel> createState() => _AgentPanelState();
}

class _AgentPanelState extends State<_AgentPanel> {
  final TextEditingController _instructionController = TextEditingController(
    text: 'Please handle this todo and report the result.',
  );

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final todo = widget.todo;
    final conversation = todo?.conversations[widget.selectedAgent];
    final isRunning = widget.runningAgent != null;
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agent',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    todo == null ? 'Select a todo first' : todo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isRunning)
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colorScheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<AgentKind>(
          segments: const [
            ButtonSegment<AgentKind>(
              value: AgentKind.codex,
              label: Text('Codex'),
              icon: Icon(Icons.terminal_outlined),
            ),
            ButtonSegment<AgentKind>(
              value: AgentKind.claudeCode,
              label: Text('Claude'),
              icon: Icon(Icons.code_outlined),
            ),
            ButtonSegment<AgentKind>(
              value: AgentKind.openClaw,
              label: Text('OpenClaw'),
              icon: Icon(Icons.hub_outlined),
            ),
          ],
          selected: <AgentKind>{widget.selectedAgent},
          onSelectionChanged: isRunning
              ? null
              : (selection) => widget.onAgentChanged(selection.first),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _instructionController,
          enabled: todo != null && !isRunning,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Instruction',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.assignment_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: todo == null || isRunning || widget.onRun == null
              ? null
              : () => widget.onRun!(_instructionController.text),
          icon: Icon(
            conversation == null
                ? Icons.play_arrow_outlined
                : Icons.redo_outlined,
          ),
          label: Text(conversation == null ? 'Send to agent' : 'Continue'),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  header,
                  const SizedBox(height: 16),
                  if (conversation != null)
                    _ConversationSummary(conversation: conversation)
                  else
                    Text(
                      'No saved conversation for ${widget.selectedAgent.label}.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (conversation == null || conversation.runs.isEmpty)
                    _AgentEmptyState(agent: widget.selectedAgent)
                  else
                    ...conversation.runs.map(
                      (run) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AgentRunCard(run: run),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationSummary extends StatelessWidget {
  const _ConversationSummary({required this.conversation});

  final AgentConversation conversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sessionId = conversation.sessionId.trim().isEmpty
        ? 'Not reported yet'
        : conversation.sessionId;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${conversation.agent.label} conversation',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          SelectableText(
            'Session ID: $sessionId',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentRunCard extends StatelessWidget {
  const _AgentRunCard({required this.run});

  final AgentRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = run.succeeded ? colorScheme.primary : colorScheme.error;
    final output = run.error?.trim().isNotEmpty == true
        ? run.error!.trim()
        : run.output.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                run.succeeded
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                size: 18,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  run.succeeded ? 'Completed' : 'Failed',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: statusColor,
                  ),
                ),
              ),
              Text(
                _formatDateTime(run.finishedAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (run.instruction.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              run.instruction.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SelectableText(
            output.isEmpty ? '(No output)' : output,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _AgentEmptyState extends StatelessWidget {
  const _AgentEmptyState({required this.agent});

  final AgentKind agent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          'Send this todo to ${agent.label}; the result and session id will be saved here.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
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
                          fontWeight: FontWeight.w700,
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
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
