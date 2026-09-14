---
name: generate-workspace-readme
description: Scan the current workspace and write or update a comprehensive, production-grade README.md. Explains system architecture, important technical details, and includes visual flowcharts/Mermaid diagrams representing process flows, along with standard sections such as overview, features, prerequisites, setup, usage, project structure, and configuration. Use when the user asks to create, update, or audit a project README.md.
---

# Generate Workspace README Skill

Use this skill to inspect a project workspace and create or refresh a high-quality, comprehensive `README.md` that serves as both an onboarding guide and an architectural reference.

## Execution Workflow

### 1. Workspace Analysis & Codebase Exploration
Before writing or modifying the README, systematically analyze the project structure and contents:
- **Project Type & Metadata**:
  - Check package manifests: `package.json`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `go.mod`, `pom.xml`, etc.
  - Read application names, versions, author information, license, and primary third-party dependencies.
- **Entry Points & Execution Flow**:
  - Identify main files: `main.py`, `app.py`, `index.ts`, `server.js`, `cmd/main.go`, etc.
  - Check scripts in package configs (e.g. `npm scripts`, `Makefile`, `Dockerfile`, `docker-compose.yml`).
- **Configuration & Environment**:
  - Look for `.env.example`, `config.yaml`, `settings.py`, or similar config files to document required variables and settings.
- **Existing Documentation**:
  - Read existing `README.md` (if any), docs folders (`docs/`), API specs, or inline comments to preserve domain knowledge and project goals.

### 2. Architecture & Process Flow Synthesis
Synthesize the technical design:
- **System Architecture**:
  - Detail components (Frontend, API layer, Business logic, Background workers, Database, External APIs).
- **Process Flow / Sequence Flowcharts**:
  - Design clear Mermaid diagrams illustrating key data flows, request lifecycles, or state transitions.
  - Example flowchart formats:
    - Architecture Overview: `flowchart TD` or `graph TD` showing component hierarchy and data flow.
    - User/Request Sequence: `sequenceDiagram` for authentication flows, API request-response cycles, or pipeline processing.
    - State Machine: `stateDiagram-v2` for task processing or status lifecycles.

### 3. README Document Structure
Write or update `README.md` in the project root adhering to the following structured layout:

```markdown
# [Project Name]

[Concise, impactful tagline describing what the project does and its core value proposition]

[![License](https://img.shields.io/badge/license-MIT-blue.svg) <!-- If license detected -->]

---

## 📌 Overview
- Provide a clear summary of the project purpose, problem solved, and target audience.
- Highlight key capabilities and differentiator points.

## ✨ Key Features
- **Feature 1**: Description.
- **Feature 2**: Description.
- **Feature 3**: Description.

## 🏗️ Architecture & System Design
Provide an explanation of system design, key modules, data contracts, and external integrations.

### Process Flow
\`\`\`mermaid
flowchart TD
    A[Client / User] -->|Input| B[API Gateway / Controller]
    B --> C[Service / Business Logic]
    C --> D[(Database / Cache)]
    C --> E[External Service / Model]
    E --> C
    C --> B
    B -->|Response| A
\`\`\`

## ⚙️ Tech Stack & Prerequisites
- **Languages & Runtimes**: (e.g., Python 3.11+, Node.js 20+, Go 1.22)
- **Frameworks & Core Libraries**: (e.g., FastAPI, React, PyTorch)
- **Infrastructure & Storage**: (e.g., PostgreSQL, Redis, Docker)
- **External Dependencies / Tools**: (e.g., API keys, system packages)

## 🚀 Getting Started

### 1. Prerequisites
List required runtime versions and system tools.

### 2. Installation
Step-by-step instructions:
\`\`\`bash
# Clone the repository (if applicable)
git clone <repo-url>
cd <project-folder>

# Install dependencies
[dependency install command]
\`\`\`

### 3. Configuration
Explain environment variables, config files, and copy instructions:
\`\`\`bash
cp .env.example .env
\`\`\`
Provide a table or bulleted list of essential environment variables:
| Variable | Description | Required | Default |
|---|---|---|---|
| `PORT` | Service port | No | `8000` |
| `API_KEY` | Authentication key | Yes | - |

## 💻 Usage & Running

### Development Mode
\`\`\`bash
[dev command, e.g., npm run dev / uvicorn main:app --reload]
\`\`\`

### Production Build / Containerization
\`\`\`bash
[docker build or npm run build commands]
\`\`\`

## 📂 Project Structure
Provide a visual directory tree showing essential files and their purposes:
\`\`\`text
project-root/
├── src/               # Application source code
│   ├── api/           # Route handlers and controllers
│   ├── services/      # Core business logic
│   └── models/        # Data schemas and entities
├── tests/             # Unit and integration test suites
├── config/            # Configuration management
├── Dockerfile         # Container definition
└── README.md          # Project documentation
\`\`\`

## 🧪 Testing & Quality
Explain how to run tests, linters, and type checkers:
\`\`\`bash
[test command, e.g., pytest / npm test]
\`\`\`

## 🤝 Contributing & License
- Include brief contributing guidelines or reference to `CONTRIBUTING.md`.
- State the project license (e.g., MIT, Apache 2.0, Proprietary) or link to `LICENSE`.
```

### 4. Quality Standards & Polish
- **Accurate & Non-Fictional**: Document actual scripts, flags, ports, and environment variables derived directly from code.
- **No Placeholders**: Do not leave unresolved `TODO` or `lorem ipsum` text. If an area is undetermined, provide a sensible default or note that it can be configured.
- **Clickable Links**: When referencing other files in the workspace (such as `.env.example`, `LICENSE`, `src/`), make them clickable markdown links using `file:///`.
- **Mermaid Syntax Validation**: Ensure all node labels with special characters (parentheses, slashes, brackets) are quoted to prevent Mermaid rendering errors.
