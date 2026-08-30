# CuraVault Control Site Engineering Constitution

- Never push directly to `main`; work through isolated branches or worktrees and reviewed pull requests.
- Preserve the existing Supabase authentication, `admin_users` allow-list, and RLS model. Never weaken authorization for convenience.
- Browser code must never contain a Supabase service-role key, GitHub credential, OpenAI/Codex credential, signing material, or another secret.
- Development-control records are administrative metadata only. They must never contain CuraVault patient data, medical records, attachment contents, credentials, or raw CI logs.
- High-risk approval must be attributable to one authenticated Owner. Audit records are append-only and must not be silently rewritten.
- Phase 1 has no remote execution, Codex execution, GitHub write, autonomous merge, deployment, or secret-management capability. Future execution requires a separate security architecture review.
- Use least privilege. Keep support and billing out of development-control write paths unless a dedicated, reviewed permission is introduced.
