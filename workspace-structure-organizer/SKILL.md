---
name: workspace-structure-organizer
description: Reorganize workspace files and folder structure according to standard architectural best practices, clean up misplaced artifacts or temporary files, and update or create .gitignore accordingly. Use when the user wants to clean up, restructure, reorganize files/folders, or establish proper .gitignore rules in a workspace.
---

# Workspace Structure Organizer Skill

Use this skill when the user asks to reorganize the directory layout of a workspace, establish clean project folder conventions, eliminate root clutter, and ensure a robust `.gitignore` is in place.

## Execution Workflow

### 1. Workspace Discovery and Stack Identification
- Inspect the root directory and subdirectories using `list_dir` to assess:
  - **Project Ecosystem**: Identify primary languages and frameworks (e.g., Python, Node.js/TypeScript, Go, Rust, Java/Maven/Gradle, Web/Mobile, Multi-service).
  - **Repository Type**: Determine if it is a single-module project, mono-repo, or polyglot workspace.
  - **Git Status**: Check if the project is a Git repository (`.git` exists) and if there are uncommitted changes before moving files.

### 2. Layout Audit & Antipattern Detection
Identify common organizational issues:
- **Root Pollution**: Source code, test scripts, scratch notebooks, mock data, or ad-hoc scripts placed directly in the project root.
- **Missing Conventional Directories**:
  - `src/` (or `<package_name>/`): Application source code.
  - `tests/`: Automated unit, integration, and end-to-end tests.
  - `docs/`: Technical documentation, guides, or specifications.
  - `scripts/` or `tools/`: Utility, maintenance, migration, or automation scripts.
  - `config/`: Configuration templates, schemas, and presets.
  - `assets/` or `static/`: Static files, images, icons, or media.
- **Accidentally Committed Artifacts**: Virtual environments (`.venv/`, `env/`), build outputs (`dist/`, `build/`, `out/`), dependency folders (`node_modules/`), cache directories (`__pycache__/`, `.pytest_cache/`), and local secrets (`.env`).

### 3. Plan Proposed Restructuring
Formulate a clean, idiomatic structure based on ecosystem conventions:
- **Python (Package / App Layout)**:
  - `src/<package_name>/` or `<package_name>/` for modules.
  - `tests/` mirroring the package hierarchy.
  - Configuration files (`pyproject.toml`, `setup.cfg`, `requirements.txt`) in the root.
- **Node / TypeScript Layout**:
  - `src/` for source files (`index.ts`, `components/`, `services/`, `utils/`).
  - `tests/` or `__tests__/` for test suites.
  - `dist/` or `build/` for compiled output (ignored by git).
- **Multi-Service / Monorepo**:
  - `apps/` or `services/` for deployable services.
  - `packages/` or `libs/` for shared libraries.

> [!IMPORTANT]
> Propose the planned file moves to the user and confirm whether imports, test configurations, or build scripts need updating to match the new paths.

### 4. Execute File Moves Safely
- If the repository uses Git, prefer moving tracked files using `git mv` via `run_command` to preserve commit history and file tracking:
  ```powershell
  git mv old_path new_path
  ```
- If moving untracked files or creating new directory scaffolding, ensure parent directories exist before moving files.
- Update import paths in source code and test files (e.g., Python `from ... import`, TypeScript `import ... from`) if moving modules breaks existing imports.
- Update configuration paths in CI/CD, Dockerfiles, entry point scripts, or test runners.

### 5. Update or Create `.gitignore`
Inspect the existing `.gitignore` (or create a new one in the project root if missing). Ensure it covers:
- **Operating System Artifacts**:
  - Windows: `Thumbs.db`, `ehthumbs.db`, `Desktop.ini`, `$RECYCLE.BIN/`
  - macOS: `.DS_Store`, `.AppleDouble`, `.LSOverride`
  - Linux: `*~`, `.fuse_hidden*`
- **IDE & Editor Settings**:
  - `.vscode/` (or keep only `.vscode/extensions.json`, ignore `.vscode/*` except settings if team-shared)
  - `.idea/`, `*.swp`, `*.swo`, `*~`
- **Ecosystem & Build Caches**:
  - **Python**: `__pycache__/`, `*.py[cod]`, `*$py.class`, `.pytest_cache/`, `.mypy_cache/`, `.ruff_cache/`, `.coverage`, `htmlcov/`, `dist/`, `build/`, `*.egg-info/`, `.venv/`, `env/`, `ENV/`
  - **Node/JavaScript**: `node_modules/`, `npm-debug.log*`, `yarn-debug.log*`, `yarn-error.log*`, `lerna-debug.log*`, `.pnpm-debug.log*`, `dist/`, `build/`, `.next/`, `.nuxt/`, `.turbo/`
  - **General**: `.cache/`, `*.log`, `tmp/`, `temp/`
- **Secrets & Sensitive Files**:
  - `.env`, `.env.local`, `.env.*.local`, `*.pem`, `*.key`, `secrets.yaml`
  - Maintain a committed template such as `.env.example` with dummy values.

### 6. Verification and Final Report
- Check git status (`git status -s`) using `run_command` to ensure all intended changes are tracked cleanly and no unwanted files are staged.
- Provide a clear before-and-after tree diagram or bullet list showing the reorganized workspace.
- Include clickable links to the newly organized folders and `.gitignore`.
