## Added Requirement

Type: Feature

Summary: Change the top quick-add behavior so clicking Add opens a dialog instead of adding inline. The dialog lets the user enter a todo title, choose a priority level displayed in Chinese, and choose a date for the todo.

Acceptance Criteria:
- Clicking the top Add button opens an add-todo dialog.
- The dialog has a todo title input.
- The dialog lets the user choose priority with Chinese labels.
- The dialog lets the user choose a date.
- Confirming the dialog creates the todo with the selected title, priority, and date.

## Added Requirement

Type: Feature

Summary: The add-todo dialog should allow entering both todo name and todo details. Todo name is required, and details are optional.

Acceptance Criteria:
- The add-todo dialog has a required todo name field.
- The add-todo dialog has an optional todo details field.
- Creating a todo saves both the name and the optional details.

## Added Requirement

Type: UI Polish

Summary: Simplify the top bar by removing the window-style dots, app name, and selected project name. Move the add-todo action to the far left of the top bar, and align the stats/settings/import/theme tools to the far right.

Acceptance Criteria:
- The top bar no longer shows window-style dots, the app name, or the selected project name.
- The add-todo button is displayed at the far left of the top bar.
- The top-right tools and stats are aligned to the far right.
- The previous add-todo control is removed from the list toolbar.

## Added Requirement

Type: Feature

Summary: Show every agent conversation session ID on each todo item, label each session with its agent, and allow clicking a session ID to continue from that exact agent conversation.

Acceptance Criteria:
- Each todo item displays all saved agent conversation session IDs for that item.
- Each displayed session ID includes the corresponding agent label.
- Clicking a displayed session ID selects that todo item and switches the Agent workspace to the matching agent conversation.
- The selected agent conversation can be continued from the existing session instead of starting a new one.

## Added Requirement

Type: UX

Summary: Update the Agent workspace instruction input so it clears immediately after sending, while new conversations or newly selected todo items still show the default instruction message.

Acceptance Criteria:
- After sending an instruction to an agent, the instruction input is cleared.
- Selecting a different todo item resets the instruction input to the default message.
- Starting a new conversation resets the instruction input to the default message.
- Existing session continuation still sends the text the user entered before the input is cleared.

## Added Requirement

Type: UX

Summary: For multi-turn agent conversations, show the previous conversation messages in the right-side Agent history panel.

Acceptance Criteria:
- A multi-turn conversation displays every saved prior user instruction and agent response in the right-side history.
- History messages are shown in conversation order from older turns to newer turns.
- User instructions are displayed as full messages instead of one-line summaries.
- Agent responses or errors remain visible with their corresponding turn metadata.

## Added Requirement

Type: Bug Fix

Summary: Make the Agent workspace send action continue the current conversation by default when a session already exists, especially for Codex, so multi-turn history is not replaced by a newly created session on each send.

Acceptance Criteria:
- Pressing `Send to agent` on a todo/agent that already has a saved session continues that session.
- Pressing `Send to agent` without an existing session still creates a new session.
- Pressing `新会话` explicitly marks the next send as a new conversation.
- Continuing an existing session appends the new run to the previous local history instead of replacing it.

## Added Requirement

Type: UX

Summary: Adjust the right-side Agent history panel so the newest messages appear at the top, closer to the instruction box, and newly added messages remain immediately visible.

Acceptance Criteria:
- The right-side Agent history shows the latest saved run above older runs.
- When a new Agent message is added, the history panel scrolls to the top so the new message is visible.
- Switching todos, agents, or sessions starts the history panel from the top of the selected conversation.
- Existing user instructions, Agent responses, metadata, and session continuation behavior remain unchanged.
