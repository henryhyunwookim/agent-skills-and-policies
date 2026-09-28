---
trigger: always_on
---

# GitHub Repository Creation & Workspace Push Protocol

This rule defines the standard procedure whenever the user requests creating a new GitHub repository and pushing a local workspace or project.

## 1. Safety & .gitignore Verification
- Always ensure a proper `.gitignore` file exists in the workspace root before staging any files.
- Ensure the `.gitignore` excludes:
  - Secrets and environment files (`.env`, `*.key`, `*.pem`, `*.token`).
  - System files (`.DS_Store`, `Thumbs.db`, `desktop.ini`).
  - Build, cache, and dependency folders (`node_modules/`, `__pycache__/`, `.venv/`, `dist/`, `build/`).
  - IDE-specific directories (`.idea/`, `.vscode/`).

## 2. Git Initialization
- Check if `.git` already exists (`git status`).
- If not initialized, initialize with the default branch `main`:
  `git init -b main`
- Stage files (`git add .`) and review staged status (`git status`).
- Create an initial commit with a descriptive message:
  `git commit -m "Initial commit: ..."`

## 3. Authentication & Credential Discovery
- On environments with Git Credential Manager configured, retrieve the stored GitHub token non-interactively:
  ```powershell
  $cred = ("protocol=https`nhost=github.com" | git credential fill) -split "`r?`n"
  $token = ($cred | Where-Object { $_ -match '^password=' }) -replace '^password=', ''
  ```
- Alternatively, check if the GitHub CLI (`gh`) is available (`gh auth status`).

## 4. Remote Repository Creation
- **Repository Visibility**: Default to **private** (`private: true`) unless the user explicitly requested a public repository.
- **Repository Name**: Use the name specified by the user, or default to the workspace root directory name.
- Create the repository via GitHub REST API:
  - Method: `POST https://api.github.com/user/repos`
  - Headers:
    - `Authorization: Bearer <token>`
    - `User-Agent: Antigravity`
    - `Accept: application/vnd.github+json`
  - Body: `{"name": "<repo_name>", "private": true, "description": "<description>"}`
- If using `gh` CLI:
  `gh repo create <repo_name> --private`

## 5. Remote Configuration & Push
- Set remote origin:
  `git remote add origin https://github.com/<owner>/<repo_name>.git`
- If origin already exists, verify or update with:
  `git remote set-url origin https://github.com/<owner>/<repo_name>.git`
- Push to GitHub with upstream tracking:
  `git push -u origin main`

## 6. Verification & Reporting
- Verify remote repository contents via GitHub API (`GET /repos/<owner>/<repo>/contents`) or `git ls-remote origin`.
- Provide the user with the direct repository URL (`https://github.com/<owner>/<repo_name>`).
