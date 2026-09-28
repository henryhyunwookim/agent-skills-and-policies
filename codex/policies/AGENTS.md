<!-- shared-agent-policy:start -->
# Shared Global Agent Rules

## Cloud Deployments and Infrastructure Policy
- **NO AUTOMATIC CLOUD DEPLOYMENTS**: Under NO circumstances should the agent automatically execute cloud deployments (such as `gcloud builds submit`, `gcloud run deploy`, AWS CLI/CDK/SAM deployments, Azure CLI deployments, Terraform/Pulumi apply, Vercel/Netlify production deploys, or any cloud infrastructure provisioning) without prior review and explicit user confirmation.
- **Mandatory Verification Gate**: Cloud deployment costs significant time and money. The agent MUST let the user check and verify the changes locally first.
- **Explicit User Approval Required**: The agent must explain the planned deployment steps, show the changes/diffs, and ask the user for explicit approval before running any deployment command.

## Git Commit and Version Control Policy
- **NO UNREQUESTED AUTOMATIC COMMITS**: Under NO circumstances should the agent automatically execute Git staging (`git add`), commits (`git commit`), or pushes (`git push`) without an explicit, unambiguous version control command from the user in their **current prompt**.
- **Strict Per-Turn Scope Isolation (No Carryover)**: A command or directive to commit/push (e.g., `/safe-git-commit`, *"commit and push"*, *"save to git"*) is strictly a **single-turn, one-shot action**. It NEVER carries over across conversation turns or subsequent follow-up requests.
- **Subsequent Follow-Ups Are Uncommitted File Edits**: When a user asks follow-up questions or makes refinement requests (e.g., *"also add section X"*, *"adjust wording"*, *"highlight permanent memory"*), the agent MUST strictly edit the files, show the diffs/results, and STOP. Never commit or push without a fresh, explicit commit directive in that specific prompt.
- **Content Requests != Commit Requests**: Directives that specify *what* to edit or write never imply or authorize a commit.

# Global Rule: Root Directory Cleanliness & Minimal Root Policy

## Core Mandate
- **MINIMAL ROOT DIRECTORY**: The root directory of any repository or workspace must be kept clean, minimal, and uncluttered. Under NO circumstances should unnecessary files, scripts, or application code be placed directly in the repository root.
- **Allowed Root Files Only**:
  The root directory must ONLY contain standard project-level configuration, metadata, and packaging manifests:
  - Standard repository manifests and dependency files (e.g., `pyproject.toml`, `requirements.txt`, `package.json`, `package-lock.json`, `Cargo.toml`, `go.mod`).
  - Standard top-level project metadata (e.g., `README.md`, `LICENSE`, `CONTRIBUTING.md`).
  - Standard container and VCS configuration files (e.g., `.gitignore`, `Dockerfile`, `.dockerignore`, `docker-compose.yml`).
  - Standard top-level workspace config directories (e.g., `.git/`, `.agents/`, `.github/`).

## Strict Prohibitions
- **NO Application Source Code in Root**: All application logic, modules, and source files must reside in dedicated directories such as `src/` or `<package_name>/`. Never place `.py`, `.ts`, `.js`, `.go`, or other source code files directly in the root.
- **NO Helper, Utility, or Automation Scripts in Root**: All operational tools, migration scripts, synchronization utilities, and helper scripts must reside in `scripts/`, `tools/`, or `deployment/`. Never dump standalone utility scripts into the root.
- **NO Execution or Batch Launchers in Root**: Batch files (`*.bat`, `*.cmd`), shell scripts (`*.sh`), or PowerShell scripts (`*.ps1`) must reside in `scripts/`, `tools/`, or `deployment/`.
- **NO Test Files in Root**: Never place test scripts, test runners, or mock data in the root directory.
- **NO Documentation Files in Root (Except Standard Readme/License)**: Detailed guides, architectural documentation, notes, specifications, and reports must reside in `docs/`.
- **NO Temporary, Scratch, or Scratchpad Files in Root**: Never create scratch files, temporary JSON/log outputs, or throwaway scripts in the root directory.

## Maintenance and Enforcement
- When creating new files, always place them in their proper subdirectories (`src/`, `scripts/`, `docs/`, etc.) rather than defaulting to the root.
- If existing root files can be cleanly organized into conventional directories, propose moving them to the user.
- Always verify the workspace root before concluding any task to ensure no new root clutter has been introduced.

# Global Rule: Never Store Testing or Debugging Files in Any Workspace

## Core Mandate
- **NEVER Store Test or Debug Files in Any Workspace**: Under NO circumstances should any file created for testing, debugging, ad-hoc inspection, experimentation, or diagnostic verification be created or stored in any workspace, repository root, or project directory.
- **NEVER Leave Testing Files Locally or in Git**: Under NO circumstances should files created for testing purposes ever be left behind in the workspace locally (as untracked or modified files) or staged/committed to Git.
- **Strict Prohibition on Agent-Generated Test Suites**: Agents must NEVER spontaneously create test suites, test files (e.g., `tests/test_*.py`, `test_*.py`), mock data files, or test runners in the workspace during development or troubleshooting.
  - Test files in `tests/` may ONLY be authored if the user has EXPLICITLY and UNAMBIGUOUSLY requested permanent repository tests.
  - Unless the user explicitly instructs the agent to create/update permanent checked-in unit tests, NO test files may be added to `tests/` or anywhere else in the repository.
- **Strict External Scratch Directory Enforcement**: ALL temporary debugging scripts, test probes, mock data files, one-off execution runners, benchmark scripts, and troubleshooting dumps MUST be stored exclusively in the agent's external scratch directory:
  `<appDataDir>\brain\<conversation-id>\scratch\`
- **Zero Workspace Litter & Test Cache Cleanup**:
  - No ephemeral test or debug scripts (e.g., ad-hoc `test_*.py`, `debug_*.py`, `temp_*.json`, `probe_*.sh`, scratch logs) may ever be placed into or left in a workspace directory.
  - Running test runners like `pytest` or `unittest` generates caches (`.pytest_cache/`, `__pycache__/`, `.coverage`). If any verification command is executed, all test caches, compiled bytecode, and test outputs must be purged immediately from the workspace.
- **Pre-Completion Workspace Verification**: Before concluding any turn or task, always run `git status` to verify that no testing, debugging, or temporary artifacts were created in or leaked into the workspace. If any are detected (whether tracked or untracked), remove them immediately before presenting results to the user.

# Cloud Deployment Policy

## Core Policy
- **NO UNREQUESTED AUTOMATIC CLOUD DEPLOYMENTS**: Under NO circumstances should the agent spontaneously execute cloud deployments (`gcloud run deploy`, `gcloud builds submit`, AWS CLI/CDK/SAM, Azure CLI, Terraform/Pulumi apply, Vercel/Netlify production deploys, etc.) during general coding, editing, or exploratory workflows without explicit user instruction.
- **Direct Execution on Clear Instructions**: When an instruction, slash command, or workflow clearly specifies or entails deploying to the cloud (e.g., `/cloud-deploy`, "deploy to cloud", "deploy to cloud run", "update cloud service", "roll out to GCP"), treat that explicit request as full authorization to execute the deployment end-to-end after running pre-flight hygiene checks, without halting to ask for redundant confirmation.
- **Approval Gate for Unprompted Deployments**: Only when a deployment has NOT been requested by the user must the agent inspect diffs, present the proposed Deployment Blueprint, and wait for confirmation before running any deployment command.

# Git Commit Policy

## 1. Core Principle: Zero Unprompted Commits
- **STRICT PROHIBITION ON AUTOMATIC COMMITS**: Under NO circumstances may the agent spontaneously stage (`git add`), commit (`git commit`), or push (`git push`) changes to any Git repository without explicit, unambiguous instruction from the user in the **current prompt**.
- **Content Requests != Commit Requests**: Directives that describe what to edit, write, or build (e.g., *"update README"*, *"add architectural decisions"*, *"highlight permanent memory"*, *"refactor this class"*, *"fix the error"*) are strictly file-editing instructions. They NEVER authorize a Git commit or push.

## 2. Strict Per-Turn Scope Isolation (No Carryover)
- **One-Shot Authorization Only**: A directive to commit or push (e.g., `/safe-git-commit`, *"commit and push"*, *"save to git"*) is strictly a **single-turn, one-shot action**.
- **NEVER Carry Over Across Turns**: Once a commit or push requested in turn N is completed, that authorization expires immediately.
- **Subsequent Follow-Ups Are Uncommitted**: If the user submits a follow-up request in turn N+1 (e.g., *"also add section X"*, *"adjust the wording"*, *"highlight memory"*), that follow-up MUST be treated as an uncommitted file edit. Do NOT stage, commit, or push unless the user explicitly commands a commit again in that specific follow-up message.
- **No Persistent "Commit Mode"**: There is no persistent session-wide "commit mode". Never assume prior commit instructions apply to ongoing or subsequent edits.

## 3. Explicit Instruction Criteria
A Git commit or push is ONLY authorized if the user's **current prompt** contains an explicit version control directive:
- Explicit slash commands: `/safe-git-commit`
- Explicit imperative phrases: *"commit this"*, *"commit and push"*, *"push to origin"*, *"save changes to git"*, *"make a commit"*
- Standard runbooks or skills that explicitly require committing as their documented terminal step (only when that runbook/skill was directly invoked in the current turn).

In all other cases:
- Inspect and modify the relevant files.
- Verify changes and show the diffs/summary to the user.
- **STOP** and wait for the user to review. Do not stage, commit, or push.

## 4. Forbidden Assumptions
- **FORBIDDEN**: Do NOT commit because "the repository was clean before".
- **FORBIDDEN**: Do NOT commit because "the edits are complete and tested".
- **FORBIDDEN**: Do NOT commit because "we committed earlier in this conversation".
- **FORBIDDEN**: Do NOT commit because "the skill workflow usually commits".
- **FORBIDDEN**: Do NOT commit because "it would be convenient or safe to save progress now".

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
<!-- shared-agent-policy:end -->
