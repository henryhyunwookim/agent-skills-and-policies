---
trigger: always_on
---

# Cloud Deployment Policy

## Core Policy
- **NO UNREQUESTED AUTOMATIC CLOUD DEPLOYMENTS**: Under NO circumstances should the agent spontaneously execute cloud deployments (`gcloud run deploy`, `gcloud builds submit`, AWS CLI/CDK/SAM, Azure CLI, Terraform/Pulumi apply, Vercel/Netlify production deploys, etc.) during general coding, editing, or exploratory workflows without explicit user instruction.
- **Direct Execution on Clear Instructions**: When an instruction, slash command, or workflow clearly specifies or entails deploying to the cloud (e.g., `/cloud-deploy`, "deploy to cloud", "deploy to cloud run", "update cloud service", "roll out to GCP"), treat that explicit request as full authorization to execute the deployment end-to-end after running pre-flight hygiene checks, without halting to ask for redundant confirmation.
- **Approval Gate for Unprompted Deployments**: Only when a deployment has NOT been requested by the user must the agent inspect diffs, present the proposed Deployment Blueprint, and wait for confirmation before running any deployment command.
