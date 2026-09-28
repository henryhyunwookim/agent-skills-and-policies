---
name: generate-workspace-readme
description: Intelligently create or update a production-grade README.md. If an existing README exists, it first analyzes its tone, structure, and content before scanning the workspace to update it. If no README exists, it diagnoses the repository type to craft a tailored, project-relevant structure (including significant technical and architectural decisions where appropriate) rather than using a generic template. Use when the user asks to create, update, or audit a project README.md.
---

# Generate Workspace README Skill

Use this skill to inspect a project workspace and create or refresh a high-quality, comprehensive `README.md` that serves as an accurate onboarding guide and architectural reference tailored specifically to the project's nature.

## Core Philosophy

A `README.md` should never be blindly generated from a rigid, one-size-fits-all template.
- **When a README already exists**: Understand and respect its existing structure, style, and domain-specific knowledge. Update outdated facts and augment deficiencies without destroying its established identity.
- **When no README exists**: Diagnose the specific *kind* of repository first (e.g., CLI tool, library/SDK, backend service, web app, agent customization/dotfiles, data science/ML pipeline, monorepo) and draft a structure tailored to that domain.
- **Capture Significant Technical & Architectural Decisions**: When a system embodies deliberate technical trade-offs, non-obvious engineering decisions, or intentional architectural constraints (e.g., framework/runtime selection, storage paradigms, state management, concurrency models, protocol choices, or security boundaries), document the rationale clearly if relevant and appropriate. Maintainers and users need to understand *why* the system is structured the way it is, not just *what* commands to execute.

---

## Execution Workflow

### Step 1: Check for Existing README & Determine Strategy

First, check if `README.md` (or `README`, `readme.md`, `README.MD`) exists in the workspace root:

#### Path A: Existing README Found (Analyze & Adapt Mode)
1. **Analyze Content, Structure & Tone**:
   - Read the existing README completely.
   - Catalog existing sections, hierarchy, formatting conventions, and tone (e.g., minimal vs. exhaustive, formal vs. conversational).
   - Identify domain knowledge, custom notes, badges, disclaimers, architecture explanations, or documented decisions that must be preserved.
   - Note which parts are outdated, incomplete, or drift from the current codebase.
2. **Scan Workspace for Drift**:
   - Check if scripts, entry points, dependencies, or environment variables have changed.
   - Inspect newly added or removed directories and features.
3. **Update & Enhance**:
   - Retain the established voice, order, and custom sections of the original README.
   - Update modified commands, configuration options, and directory trees.
   - Fill in critical gaps (e.g., add missing prerequisites, document undocumented env vars, add an illustrative Mermaid diagram where complex architecture is unexplained, or capture key architectural decisions that shaped recent changes).
   - Avoid wiping out custom user-written descriptions in favor of generic boilerplate.

#### Path B: No Existing README (Diagnosis & Tailored Drafting Mode)
1. **Diagnose Repository Classification**:
   Systematically inspect the codebase to classify the repository type:
   - **Library / SDK / Reusable Package**:
     - *Indicators*: `npm package` without server entry points, `pyproject.toml` or `setup.py` building a package, Go module with exported packages, published crate in `Cargo.toml`.
     - *Key Focus*: Installation command (`npm i`, `pip install`), Quickstart with clear import & usage examples, API reference / exported types, configuration options, test/build commands, and core design decisions (e.g., zero-dependency constraints, immutability, async-first).
   - **CLI Tool / Developer Utility**:
     - *Indicators*: Executable binaries, `bin` or `cmd/` packages, argument parsers (argparse, click, cobra, commander).
     - *Key Focus*: Binary/global installation, command usage syntax, options/flags table, subcommands breakdown, shell completion or config file details, example invocations, and core technical decisions (e.g., streaming vs. buffering, subprocess isolation, terminal handling).
   - **Web Application / Backend Service / API**:
     - *Indicators*: Web frameworks (FastAPI, Express, Next.js, Django, NestJS, Spring), database configs, Dockerfiles.
     - *Key Focus*: Architecture & Mermaid process flow, Key Technical & Architectural Decisions (e.g., database choice, auth model, state management, queue/worker decoupling), Environment Variables table, Local development setup, Database migrations, Docker/production deployment, API endpoint summary.
   - **Agent Customization / Plugin / Config / Dotfiles**:
     - *Indicators*: Skills, rules, plugins, prompt templates, tool definitions, shell configurations.
     - *Key Focus*: Customization roots, discovery/loading mechanism, directory layout, guides for adding/modifying skills or rules, configuration options, and integration decisions (e.g., sync strategies, isolation models).
   - **Data Science / Machine Learning / Research**:
     - *Indicators*: Notebooks (`.ipynb`), PyTorch/TensorFlow dependencies, dataset directories, model weight configs.
     - *Key Focus*: Hardware/CUDA prerequisites, dataset preparation/download, training pipeline, evaluation/benchmarks, inference script usage, and architectural decisions (e.g., model architecture selection, precision choices, distributed vs single-node execution).
   - **Monorepo / Multi-Package Workspace**:
     - *Indicators*: `pnpm-workspace.yaml`, Turborepo, Lerna, Cargo workspace, root package coordinating multiple subpackages.
     - *Key Focus*: Workspace structure diagram, package relationship graph, root commands vs. package-specific commands, and boundary decisions (e.g., package separation criteria, shared types strategy).

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
- **Technical & Architectural Decisions Discovery (When Relevant)**:
  Investigate the codebase for deliberate engineering decisions and trade-offs that warrant documentation:
  - *Design Documents & ADRs*: Check for Architecture Decision Records (e.g., `docs/adr/`, `decisions/`, `RFCs`, or architectural specs).
  - *Code Comments & Module Docstrings*: Look for inline explanations detailing *why* a particular algorithm, pattern, library, or workaround was chosen over standard conventions.
  - *Infrastructure & Technology Stack Choices*: Identify reasons behind non-standard or pivotal tech choices (e.g., why DuckDB instead of Postgres, why WebSocket instead of polling, why custom serialization instead of protobuf, why standalone process vs in-memory worker).
  - *Architectural Constraints & Principles*: Note intentional constraints (e.g., zero runtime dependencies, offline-first operation, memory footprint ceilings, strict decoupled modularity).
  - *Relevance Filter*: Only include decisions that are **meaningful and appropriate** to understanding, operating, or contributing to this specific system. Avoid stating trivial or default choices (e.g., do not explain why Git is used for version control or why JSON is used for basic configs).

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

### Step 4: Technical & Architectural Decisions (If Relevant & Appropriate)

When the codebase demonstrates deliberate, non-trivial engineering choices, dedicate a section (e.g., `## Architectural Decisions`, `## Technical Decisions & Trade-offs`, or integrated into `## Architecture & Core Concepts`) to explain them:

- **What to Document**:
  1. **Decision & Selected Approach**: The specific architectural pattern, framework, storage engine, or design choice adopted.
  2. **Context & Motivation**: The exact technical problem, domain constraint, performance goal, or operational requirement that necessitated this choice.
  3. **Rationale & Alternatives Considered**: Why this solution was preferred over common alternatives (including trade-offs accepted, such as trading disk usage for query speed).
  4. **Consequences & Impact**: How this decision influences developer workflow, deployment, performance, or system extensibility.

- **Example Format**:
  ```markdown
  ## Technical & Architectural Decisions

  - **State Storage via DuckDB / Parquet**:
    - *Decision*: Embedded DuckDB with column-oriented Parquet files instead of a standalone relational DBMS.
    - *Rationale*: Eliminates external service dependencies for single-node deployments while delivering 10x faster analytical query performance over aggregated datasets.
    - *Trade-off*: Not suited for multi-writer concurrent transactions; writes are coordinated via an internal write-ahead queue.
  ```

- **Relevance Gate**:
  - **Include** if: The decision deviates from the industry default, involves a clear trade-off, explains non-obvious code organization, or is essential context for new contributors.
  - **Omit** if: The project is a standard boilerplate, the choices are completely conventional with no notable trade-offs, or the repository is a small single-purpose script.

---

### Step 5: Tailored README Layout Examples

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

## Architectural Decisions (Optional / If Relevant)
- **Zero Runtime Dependencies**: Uses only standard library primitives to ensure a minimal bundle footprint and eliminate supply chain security risks.
- **Async-First Execution**: Designed with non-blocking I/O throughout to avoid event loop stalls in high-throughput consumers.

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

## Technical Decisions (If Relevant)
- **Streaming JSON Processing**: Processes records as a line-delimited stream rather than buffering entire payloads in memory, allowing gigabyte-scale inputs with minimal memory overhead.

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

## Technical & Architectural Decisions
- **Decoupled Job Queue**: Asynchronous tasks are offloaded to Redis/BullMQ to prevent long-running worker processes from degrading HTTP request latency.
- **Stateless Authentication**: JWT tokens stored in HTTP-only cookies enable horizontal autoscaling without sticky session affinity.

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

### Step 6: Quality Standards & Final Checklist

- **Accurate & Non-Fictional**: Every command, script, environment variable, and port must match actual files in the workspace. Never invent placeholders like `npm start` if only `npm run dev` exists.
- **Respect Existing Content**: Never discard customized notes, external links, or unique historical context already written in an existing README.
- **Meaningful Architectural Decisions**: Only document technical and architectural decisions if they are genuinely relevant, non-trivial, and appropriate for the system's scope. Avoid stating the obvious or inventing artificial rationales.
- **Clickable File Links**: When referencing key local files in the workspace (such as `.env.example`, `LICENSE`, `docker-compose.yml`), use markdown links (`[filename](file:///absolute/path/to/file)` or relative links where appropriate).
- **Clean Structure**: Ensure clean markdown with accurate heading levels (`#` -> `##` -> `###`), no broken code fences, and validated Mermaid syntax.
