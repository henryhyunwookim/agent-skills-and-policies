---
name: workspace-organizer
description: Organize and standardize workspace architecture, eliminate root clutter, maintain .gitignore hygiene, and enrich script and code files with detailed step-by-step comments, architectural rationale, docstrings, and strict type annotations. Use when the user wants to clean up, restructure, organize files/folders, establish .gitignore rules, or improve script/code quality through documentation, deep commenting, typing, and docstrings across a workspace.
---

# Workspace Organizer Skill

Use this skill when the user asks to reorganize the directory layout of a workspace, establish clean project folder conventions, eliminate root clutter, maintain a robust `.gitignore`, or enrich script and code files with detailed step-by-step comments, architectural rationale, docstrings, and strict type annotations.

## Execution Workflow

### 1. Workspace Discovery and Stack Identification
- Inspect the root directory and subdirectories using `list_dir` to assess:
  - **Project Ecosystem**: Identify primary languages and frameworks (e.g., Python, Node.js/TypeScript, Go, Rust, Java/Maven/Gradle, Web/Mobile, Multi-service).
  - **Repository Type**: Determine if it is a single-module project, mono-repo, polyglot workspace, or automation/scripts repository.
  - **Git Status**: Check if the project is a Git repository (`.git` exists) and if there are uncommitted changes before moving or editing files using `run_in_terminal`:
    ```powershell
    git status -s
    ```

### 2. Layout Audit & Antipattern Detection
Identify common organizational issues across the workspace:
- **Root Pollution**: Source code, test scripts, scratch notebooks, mock data, or ad-hoc scripts placed directly in the project root.
- **Missing Conventional Directories**:
  - `src/` (or `<package_name>/`): Application source code.
  - `tests/`: Automated unit, integration, and end-to-end tests.
  - `docs/`: Technical documentation, guides, or specifications.
  - `scripts/` or `tools/`: Utility, maintenance, migration, setup, or automation scripts.
  - `config/`: Configuration templates, schemas, and presets.
  - `assets/` or `static/`: Static files, images, icons, or media.
- **Accidentally Committed Artifacts**: Virtual environments (`.venv/`, `env/`), build outputs (`dist/`, `build/`, `out/`), dependency folders (`node_modules/`), cache directories (`__pycache__/`, `.pytest_cache/`), and local secrets (`.env`).

### 3. Plan Proposed Restructuring
Formulate a clean, idiomatic structure based on ecosystem conventions:
- **Python (Package / App Layout)**:
  - `src/<package_name>/` or `<package_name>/` for modules.
  - `tests/` mirroring the package hierarchy.
  - `scripts/` for standalone automation or CLI utilities.
  - Configuration files (`pyproject.toml`, `setup.cfg`, `requirements.txt`) in the root.
- **Node / TypeScript Layout**:
  - `src/` for source files (`index.ts`, `components/`, `services/`, `utils/`).
  - `tests/` or `__tests__/` for test suites.
  - `scripts/` for operational or build helper scripts.
  - `dist/` or `build/` for compiled output (ignored by git).
- **Multi-Service / Monorepo**:
  - `apps/` or `services/` for deployable services.
  - `packages/` or `libs/` for shared libraries.
  - `tools/` or `scripts/` for workspace-wide automation.

> [!IMPORTANT]
> Propose the planned file moves to the user and confirm whether imports, test configurations, or build scripts need updating to match the new paths.

### 4. Execute File Moves Safely
- If the repository uses Git, prefer moving tracked files using `git mv` via `run_in_terminal` to preserve commit history and file tracking:
  ```powershell
  git mv old_path new_path
  ```
- If moving untracked files or creating new directory scaffolding, ensure parent directories exist before moving files.
- Update import paths in source code and test files (e.g., Python `from ... import`, TypeScript `import ... from`) if moving modules breaks existing imports.
- Update configuration paths in CI/CD, Dockerfiles, entry point scripts, or test runners.

### 5. Script & Code File Enrichment (Documentation, Comments, & Types)
When organizing a workspace or auditing scripts, systematically review all script and utility files (e.g., under `scripts/`, `tools/`, `bin/`, or project root) and core modules. Code should not merely be functional; it must be self-documenting, pedagogical, robustly typed, and thoroughly commented.

#### A. File & Module Headers
Ensure every standalone script and module begins with clear, high-level header documentation:
- **Purpose**: What the script does in 1–2 clear, concise sentences.
- **Usage / CLI Invocation**: Provide real command examples, expected arguments, and optional flags (e.g., `python script.py --flag value`).
- **Prerequisites & Dependencies**: Runtime requirements (e.g., Python version, PowerShell version, external CLIs, package dependencies).
- **Inputs & Outputs**: Expected environment variables, input files, generated output artifacts, caches, or logs.

#### B. Type Annotations & Strict Signatures
Enforce explicit, robust typing across all functions, methods, and parameters:
- **Python**:
  - Add PEP 484 type hints for all parameters and return types (e.g., `def run_task(timeout: int = 30) -> list[str]:`).
  - Import necessary typing constructs (`from typing import Optional, Union, Callable, Any, Dict, List, Tuple`).
  - For Python 3.10+ codebases, use `from __future__ import annotations` and prefer standard built-in generics (`list[str]`, `dict[str, Any]`, `X | None`).
- **TypeScript / JavaScript**:
  - Enforce explicit TypeScript types and interfaces; eliminate untyped `any` parameters.
  - For plain JavaScript (`.js`, `.mjs`), add JSDoc `@param {Type}` and `@returns {Type}` annotations so editors and tools can infer types reliably.
- **PowerShell**:
  - Use `[CmdletBinding()]` on all automation scripts and functions.
  - Add explicit parameter types (e.g., `[string]$FilePath`, `[switch]$Force`, `[int]$MaxRetries = 3`).
  - Provide comment-based help blocks (`<# .SYNOPSIS ... .DESCRIPTION ... .PARAMETER ... .EXAMPLE #>`).
- **Bash / Shell**:
  - Include proper shebang (`#!/usr/bin/env bash`).
  - Set strict error handling (`set -euo pipefail`).
  - Provide a standardized `usage()` function with parameter parsing and descriptive help output.

#### C. Function & Class Docstrings
- Document public classes, functions, and methods following project conventions (Google style, Sphinx/reST, or JSDoc/TSDoc).
- Clearly explain parameters, expected types, return structures, side effects, and potential exceptions or errors raised.

#### D. Exhaustive Inline Comments & Pedagogical Logic Clarification
Never leave non-trivial code blocks uncommented. Provide pervasive, high-clarity inline comments across all scripts:
- **Visual Section Banners**: Group functions and logic into clear architectural zones using distinct banners (e.g., `# ===========================================================================`, `# ---------------------------------------------------------------------------` for constants, caching, core logic, API inference, helpers, CLI entrypoint).
- **Sequential Step-by-Step Flow**: Number and document sequential pipeline stages (`# Step 1: Initialize local directory scaffolding`, `# Step 2: Ingest and validate cache`, `# Step 3: Compute embeddings`).
- **Architectural & Design Rationale ("The Why")**: Explain *why* specific patterns or configurations are used (e.g., why `@st.cache_resource` is used to prevent model reloading; why REST transport is chosen; why specific batch sizes or smoothing constants like RRF $k=60$ are selected).
- **Mathematical & Algorithmic Formulas**: For mathematical operations, vector calculations (e.g., $\ell_2$ normalization, cosine distance), heuristic scores, or regex patterns, explicitly write out the formula or mechanism in comments.
- **Defensive & Fallback Logic**: In every `try/except` or conditional branch, explain why the error might occur, which specific exceptions are caught (e.g., distinguishing invalid auth credentials from transient HTTP 429 quota exhaustion), and what the fallback behavior achieves.
- **UI & State Lifecycle Notes**: In frontend/interactive applications (Streamlit, React, Gradio, CLI prompts), document state persistence, session keys, event handlers, rerun triggers, and UI resets.
- **Avoid Trivial Syntax Echoes**: Avoid comments that only restate primitive code (e.g., don't write `# set x to 1` above `x = 1`); instead explain the operational intent and business logic.

#### E. Outdated Documentation Maintenance & Drift Correction
- Check existing comments and docstrings against current implementations:
  - Correct renamed parameters, altered return types, or updated default values.
  - Remove references to removed arguments or obsolete workflows.
  - Preserve valid domain explanations and architectural notes while fixing factual inaccuracies.

### 6. Update or Create `.gitignore`
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

### 7. Verification and Final Report
- Check git status (`git status -s`) using `run_in_terminal` to ensure all intended changes are tracked cleanly and no unwanted files are staged.
- Run type checkers or syntax checks where available (e.g., `python -m py_compile <file>`, `tsc --noEmit`, etc.) to confirm that added annotations are syntactically valid.
- Provide a clear before-and-after tree diagram or bullet list showing the reorganized workspace.
- Include clickable links to the newly organized folders, updated scripts, and `.gitignore`.
