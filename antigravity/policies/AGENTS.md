# Antigravity Global Agent Rules

## Cloud Deployments and Infrastructure Policy
- **NO AUTOMATIC CLOUD DEPLOYMENTS**: Under NO circumstances should the agent automatically execute cloud deployments (such as `gcloud builds submit`, `gcloud run deploy`, AWS CLI/CDK/SAM deployments, Azure CLI deployments, Terraform/Pulumi apply, Vercel/Netlify production deploys, or any cloud infrastructure provisioning) without prior review and explicit user confirmation.
- **Mandatory Verification Gate**: Cloud deployment costs significant time and money. The agent MUST let the user check and verify the changes locally first.
- **Explicit User Approval Required**: The agent must explain the planned deployment steps, show the changes/diffs, and ask the user for explicit approval before running any deployment command.

## Git Commit and Version Control Policy
- **NO UNREQUESTED AUTOMATIC COMMITS**: Under NO circumstances should the agent automatically execute Git staging (`git add`), commits (`git commit`), or pushes (`git push`) without an explicit, unambiguous version control command from the user in their **current prompt**.
- **Strict Per-Turn Scope Isolation (No Carryover)**: A command or directive to commit/push (e.g., `/safe-git-commit`, *"commit and push"*, *"save to git"*) is strictly a **single-turn, one-shot action**. It NEVER carries over across conversation turns or subsequent follow-up requests.
- **Subsequent Follow-Ups Are Uncommitted File Edits**: When a user asks follow-up questions or makes refinement requests (e.g., *"also add section X"*, *"adjust wording"*, *"highlight permanent memory"*), the agent MUST strictly edit the files, show the diffs/results, and STOP. Never commit or push without a fresh, explicit commit directive in that specific prompt.
- **Content Requests != Commit Requests**: Directives that specify *what* to edit or write never imply or authorize a commit.