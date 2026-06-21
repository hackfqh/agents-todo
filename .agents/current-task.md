## New Feature Requirement

Type: Feature

Summary: Add two small tools in the Todo Desk top-right area. One tool opens an issue importer where the user can paste an internal GitLab or GitHub issue URL, fetch the issue title/body through the relevant API, preview the content, and add it to the current project's todo list. The other tool opens settings where GitLab and GitHub tokens can be configured.

Acceptance Criteria:
- A settings UI exists for GitLab and GitHub tokens.
- An issue import UI exists for GitLab/GitHub issue URLs.
- GitLab URLs like `https://gitpd.paodingai.com/cheftin/docs_docdot/-/issues/20` are parsed.
- Fetched issue title/body can be added as a todo title/details.
- Token settings persist locally.

## Added Requirement

The top-right token-specific button should become a general settings button. GitLab/GitHub token configuration remains available inside settings as one settings section/item rather than the whole settings concept.

- When an agent finishes processing a todo and returns a result, show a transient in-app notification so the completion is visible immediately.

- Prefer a native desktop notification when an agent finishes; use the in-app notification only as a fallback when the system notification cannot be delivered.

- Add a Settings toggle for enabling or disabling agent completion notifications, and persist the preference locally.
