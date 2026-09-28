---
trigger: always_on
---

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