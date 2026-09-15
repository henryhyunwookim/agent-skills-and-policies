---
name: generate-workspace-readme
description: Intelligently create or update a production-grade README.md. If an existing README exists, it first analyzes its tone, structure, and content before scanning the workspace to update it. If no README exists, it diagnoses the repository type to craft a tailored, project-relevant structure rather than using a generic template. Use when the user asks to create, update, or audit a project README.md.
---

# Generate Workspace README Skill

Use this skill to inspect a project workspace and create or refresh a high-quality, comprehensive `README.md` that serves as an accurate onboarding guide and architectural reference tailored specifically to the project's nature.

## Core Philosophy

A `README.md` should never be blindly generated from a rigid, one-size-fits-all template.
- **When a README already exists**: Understand and respect its existing structure, style, and domain-specific knowledge. Update outdated facts and augment deficiencies without destroying its established identity.
- **When no README exists**: Diagnose the specific *kind* of repository first (e.g., CLI tool, library/SDK, backend service, web app, agent customization/dotfiles, data science/ML pipeline, monorepo) and draft a structure tailored to that domain.

---

## Execution Workflow

### Step 1: Check for Existing README & Determine Strategy

First, check if `README.md` (or `README`, `readme.md`, `README.MD`) exists in the workspace root:

#### Path A: Existing README Found (Analyze & Adapt Mode)
1. **Analyze Content, Structure & Tone**:
   - Read the existing README completely.
   - Catalog existing sections, hierarchy, formatting conventions, and tone (e.g., minimal vs. exhaustive, formal vs. conversational).
   - Identify domain knowledge, custom notes, badges, disclaimers, or architecture explanations that must be preserved.
   - Note which parts are outdated, incomplete, or drift from the current codebase.
2. **Scan Workspace for Drift**:
   - Check if scripts, entry points, dependencies, or environment variables have changed.
   - Inspect newly added or removed directories and features.
3. **Update & Enhance**:
   - Retain the established voice, order, and custom sections of the original README.
   - Update modified commands, configuration options, and directory trees.
   - Fill in critical gaps (e.g., add missing prerequisites, document undocumented env vars, or add an illustrative Mermaid diagram where complex architecture is unexplained).
   - Avoid wiping out custom user-written descriptions in favor of generic boilerplate.

#### Path B: No Existing README (Diagnosis & Tailored Drafting Mode)
1. **Diagnose Repository Classification**:
   Systematically inspect the codebase to classify the repository type:
   - **Library / SDK / Reusable Package**:
     - *Indicators*: `npm package` without server entry points, `pyproject.toml` or `setup.py` building a package, Go module with exported packages, published crate in `Cargo.toml`.
     - *Key Focus*: Installation command (`npm i`, `pip install`), Quickstart with clear import & usage examples, API reference / exported types, configuration options, test/build commands.
   - **CLI Tool / Developer Utility**:
     - *Indicators*: Executable binaries, `bin` or `cmd/` packages, argument parsers (argparse, click, cobra, commander).
     - *Key Focus*: Binary/global installation, command usage syntax, options/flags table, subcommands breakdown, shell completion or config file details, example invocations.
   - **Web Application / Backend Service / API**:
     - *Indicators*: Web frameworks (FastAPI, Express, Next.js, Django, NestJS, Spring), database configs, Dockerfiles.
     - *Key Focus*: Architecture & Mermaid process flow, Environment Variables table, Local development setup, Database migrations, Docker/production deployment, API endpoint summary.
   - **Agent Customization / Plugin / Config / Dotfiles**:
     - *Indicators*: Skills, rules, plugins, prompt templates, tool definitions, shell configurations.
     - *Key Focus*: Customization roots, discovery/loading mechanism, directory layout, guides for adding/modifying skills or rules, configuration options.
   - **Data Science / Machine Learning / Research**:
     - *Indicators*: Notebooks (`.ipynb`), PyTorch/TensorFlow dependencies, dataset directories, model weight configs.
     - *Key Focus*: Hardware/CUDA prerequisites, dataset preparation/download, training pipeline, evaluation/benchmarks, inference script usage.
   - **Monorepo / Multi-Package Workspace**:
     - *Indicators*: `pnpm-workspace.yaml`, Turborepo, Lerna, Cargo workspace, root package coordinating multiple subpackages.
     - *Key Focus*: Workspace structure diagram, package relationship graph, root commands vs. package-specific commands.

2. **Draft a Tailored README Structure**:
   - Synthesize a layout tailored specifically to the diagnosed repository type.
   - Include only sections that bring value to this specific project (e.g., do not add "API Endpoints" or "Docker Deployment" to a reusable utility library or dotfiles repo).

---

### Step 2: Codebase Exploration & Fact Verification

Whether updating an existing README or drafting a new one, explore the codebase to gather precise facts:
- **Package Manifests**: Check `package.json`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `go.mod`, `pom.xml`, etc.
  - Extract project name, version, description, authors, license, and core dependencies.
- **Entry Points & Execution**:
  - Identify primary entry points (`main.py`, `app.ts`, `index.js`, `cmd/main.go`, `src/index.ts`).
  - Read runnable scripts (e.g., `scripts` in `package.json`, `Makefile`, `Justfile`, `Taskfile`).
- **Configuration & Environment**:
  - Inspect `.env.example`, `config.yaml`, `settings.py`, or similar config schemas.
  - Document required environment variables with their types, descriptions, and defaults.
- **Directory Layout**:
  - Inspect the workspace directory tree to produce an accurate, meaningful project structure snippet highlighting key paths (excluding noise like `node_modules`, `dist`, `.git`, `__pycache__`).

---

### Step 3: Architecture & Visual Diagrams (Tailored Mermaid)

Incorporate visual diagrams where they provide genuine architectural clarity, selecting the diagram type that fits the project:
- **Service / Web App Flow**: `flowchart TD` or `sequenceDiagram` showing client requests, middleware, services, and storage.
- **Data / Pipeline Processing**: `flowchart LR` showing ingest -> transform -> process -> output/storage.
- **CLI / Execution State Lifecycle**: `stateDiagram-v2` or `flowchart TD` showing input arguments -> validation -> command execution -> output format.
- **Component / Module Relationships**: `classDiagram` or `graph TD` showing core packages and how they depend on each other.

> [!IMPORTANT]
> Always quote Mermaid node labels containing special characters (parentheses, brackets, slashes) to prevent rendering syntax errors:
> e.g. `id["Client (Browser / CLI)"] --> id2["API Gateway (/api/v1)"]`

---

### Step 4: Tailored README Layout Examples

Use these examples as inspiration for drafting tailored layouts (do not force a project into an inappropriate layout):

<details>
<summary><b>Example A: Reusable Library / SDK</b></summary>

```markdown
# [Library Name]
[One-line description of what the library does and its key advantage]

## Features
- Core feature 1
- Core feature 2

## Installation
\`\`\`bash
npm install [package-name]
# or: pip install [package-name]
\`\`\`

## Quickstart
\`\`\`typescript
import { Client } from '[package-name]';
const client = new Client({ apiKey: process.env.API_KEY });
const result = await client.doSomething();
\`\`\`

## API Reference & Core Concepts
- Explanations of primary classes, functions, and interfaces.

## Configuration & Options
| Option | Type | Default | Description |
|---|---|---|---|

## Development & Testing
\`\`\`bash
npm test
npm run build
\`\`\`

## License
[License type]
```
</details>

<details>
<summary><b>Example B: CLI / Developer Tool</b></summary>

```markdown
# [Tool Name]
[Concise summary of what the tool accomplishes]

## Installation
\`\`\`bash
# Homebrew / Binary / npm / cargo install instructions
\`\`\`

## Usage
\`\`\`bash
tool-name [options] <command> [args]
\`\`\`

### Commands
- `tool-name init`: Initialize project configuration.
- `tool-name run`: Execute the primary workflow.

### Options & Flags
| Flag | Short | Description | Default |
|---|---|---|---|
| `--config` | `-c` | Path to config file | `config.json` |
| `--verbose`| `-v` | Enable verbose logging | `false` |

## Workflow / Examples
Provide 2-3 practical, copy-pasteable command examples with realistic arguments.

## Contributing & License
```
</details>

<details>
<summary><b>Example C: Web App / API / Fullstack Service</b></summary>

```markdown
# [Service Name]
[Service mission statement and core capability]

## Architecture & Data Flow
[Mermaid diagram representing frontend, API layer, workers, and database]

## Tech Stack & Prerequisites
- Runtimes, databases, and external tools required.

## Getting Started
### 1. Installation
### 2. Environment Variables
[Config table with PORT, DB_URL, API_KEYS]
### 3. Running Locally (Dev)
### 4. Database Migrations / Seeding
### 5. Production Build / Docker

## Project Structure
[Curated directory tree of src/, api/, models/, etc.]

## Testing & Quality
[Lint, unit test, integration test commands]

## License
```
</details>

---

### Step 5: Quality Standards & Final Checklist

- **Accurate & Non-Fictional**: Every command, script, environment variable, and port must match actual files in the workspace. Never invent placeholders like `npm start` if only `npm run dev` exists.
- **Respect Existing Content**: Never discard customized notes, external links, or unique historical context already written in an existing README.
- **Clickable File Links**: When referencing key local files in the workspace (such as `.env.example`, `LICENSE`, `docker-compose.yml`), use markdown links (`[filename](file:///absolute/path/to/file)` or relative links where appropriate).
- **Clean Structure**: Ensure clean markdown with accurate heading levels (`#` -> `##` -> `###`), no broken code fences, and validated Mermaid syntax.
