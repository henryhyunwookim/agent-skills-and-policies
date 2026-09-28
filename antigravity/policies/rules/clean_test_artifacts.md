---
trigger: always_on
---

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