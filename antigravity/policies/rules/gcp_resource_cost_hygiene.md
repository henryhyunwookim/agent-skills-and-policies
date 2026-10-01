# Global Rule: GCP Resource & Cost Hygiene Policy (Artifact Registry & Secret Manager)

## 1. Secret Manager Lifecycle & Free-Tier Guardrails
- **STRICT SINGLE-ACTIVE-VERSION POLICY**: Under NO circumstances should scripts, applications, or background cron jobs create unbounded new secret versions without immediately destroying or disabling superseded versions.
- **Automatic Pruning Mandatory**: Whenever a token is refreshed (e.g., OAuth tokens in `auth.py`) or credentials are synced (`sync_secrets.py`), the codebase MUST immediately query and destroy/disable prior enabled versions of that secret, ensuring only the single latest version (`latest`) remains in the `ENABLED` state.
- **Protect Free-Tier Quota**: Google Cloud provides 6 active secret versions for free per billing account. Non-sensitive configuration (e.g. recipient email addresses, non-secret flags) must NEVER be stored in Secret Manager—use Cloud Run environment variables instead.
- **Zero Dangling Versions**: Before closing any task touching GCP Secret Manager, verify that `gcloud secrets versions list <secret> --filter="state:ENABLED"` does not contain accumulating obsolete versions.

## 2. Artifact Registry Lifecycle & Retention Policies
- **MANDATORY CLEANUP POLICIES**: Every Artifact Registry repository must have an automated Cleanup Policy (retention rule) enabled. Repositories must never be left with `cleanupPolicies: null`.
- **Standard Cleanup Policy Rules**:
  1. `keep-recent-versions`: Keep only the **most recent 2 to 3 versions** of any container package (`keepCount: 2` or `3`).
  2. `delete-untagged-old`: Automatically delete untagged container image digests older than **3 days** (`tagState: UNTAGGED`, `olderThan: 259200s`).
  3. `delete-old-packages`: Automatically delete container packages older than **14 to 30 days** (`tagState: ANY`, `olderThan: 1209600s`).
- **Source-Deploy & Build Hygiene**: When deploying via `gcloud run deploy --source .` or `gcloud builds submit`, ensure the target repository is subject to active cleanup policies so old builds are automatically purged.
