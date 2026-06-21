# Todo Desk

A small Flutter desktop todo app for Windows and macOS.

## Features

- Create projects from local folders.
- Switch between projects with separate todo lists.
- Add and delete todos.
- Edit todo titles and details.
- Send a selected todo to Codex, Claude Code, or OpenClaw.
- Save agent results and conversation session IDs for later continuation.
- Run agent tools from the selected project's folder.
- Mark todos as open or done.
- Filter by all, open, or done.
- Clear completed todos.
- Persist todos locally as JSON.

## Run

Agent handling expects these CLIs to be installed and available in your shell
`PATH`:

- `codex`
- `claude`
- `openclaw`

```sh
flutter run -d macos
```

On Windows:

```sh
flutter run -d windows
```

## Test

```sh
flutter analyze
flutter test
```
