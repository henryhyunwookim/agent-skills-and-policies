---
name: clone-github-repo
description: Clone a Git or GitHub repository into the current workspace or local folder, verify the cloned contents, and inspect initial project files. Use whenever the user asks to clone a repository, import a repo from GitHub/GitLab, or fetch a remote codebase locally.
---

# Clone GitHub Repository Skill

Use this skill when the user requests to clone a Git or GitHub repository into the current local directory or a specified folder.

## Workflow

### 1. Identify Target Directory and Repository URL
- **Repository URL**:
  - Accept standard GitHub/GitLab/Bitbucket URLs (e.g., `https://github.com/<owner>/<repo>`, `https://github.com/<owner>/<repo>.git`, or SSH `git@github.com:<owner>/<repo>.git`).
  - If the user provides a shorthand like `<owner>/<repo>`, resolve it to `https://github.com/<owner>/<repo>.git`.
  - Extract the repository name (e.g., `AI-news-aggregator-KRJP` from `https://github.com/henryhyunwookim/AI-news-aggregator-KRJP`).
- **Target Folder**:
  - By default, clone into the current working directory / active workspace folder.
  - If the user specified a custom directory or subfolder name, resolve the path accordingly.
  - **Important**: Never use the `cd` command. Instead, pass the absolute path to the target folder in the `Cwd` parameter of `run_in_terminal`.

### 2. Pre-Check Destination
- Before cloning, check if a folder with the repository's name already exists in the target directory using `list_dir`.
- If the directory already exists and contains files:
  - Warn the user or ask how to proceed (e.g., clone into a different directory name, pull updates, or overwrite/clean up).
  - Do not blindly run `git clone` into an existing non-empty directory as Git will abort with an error.

### 3. Execute the Clone Command
- Use `run_in_terminal` with:
  - `CommandLine`: `git clone <repository_url>` (or `git clone <repository_url> <custom_dir_name>` if a custom name is desired).
    - If user asks for shallow clone or specific branch: add `--depth 1` or `-b <branch_name>`.
  - `Cwd`: Target folder where the cloned repo directory will be created.
  - `WaitMsBeforeAsync`: Set to a reasonable timeout (e.g., `10000` to `20000` ms) to allow the clone process to complete synchronously.

### 4. Verify Cloned Content
- Once the command succeeds, list the cloned directory using `list_dir` to confirm the folder structure and verify that files exist.
- Identify key landmark files:
  - `README.md` / `README`
  - Dependencies/package files: `requirements.txt`, `pyproject.toml`, `package.json`, `pom.xml`, `go.mod`, `Cargo.toml`, etc.
  - Environment/configuration templates: `.env.example`, `config.yaml`, `Dockerfile`, etc.

### 5. Report to User
- Provide a concise summary of the clone result including:
  - Repository name and full local path.
  - Clickable markdown links (`file:///...`) to the cloned directory and key landmark files (README, config, package files).
  - A brief note on detected project type (e.g., Python, Node.js, Go) and recommended next setup steps (e.g., virtual environment creation, dependency installation) if relevant.
