# Codex Integration Boundary

The proposed future path is: Control Site task -> server-side dispatcher -> execution policy validation -> isolated Codex worktree -> GitHub pull request -> CI -> architecture/security review -> explicit approval -> separately authorized merge or release.

Phase 2 implements a server-side policy decision and deterministic mock lifecycle evidence. Phase 3 adds a Codex provider policy, repository allow-list, SHA pin, high-risk authorization, safe evidence fields, and a typed trusted-worker transport. It does not enable the provider, invoke OpenAI in CI, call GitHub, expose a shell endpoint, trigger CI, create a pull request, merge, or deploy. Its provider configuration defaults to disabled and has no authenticated write path.

The remaining production enablement work is an isolated worker host with bounded
workspace lifecycle, read-only repository access, provider secret injection,
network isolation, job claiming, heartbeats, timeout/cancellation enforcement,
and monitoring. Browser clients must never receive execution credentials,
agents must not bypass repository `AGENTS.md` rules, and stored task/prompt
content remains untrusted data. High and Critical work never auto-merges, and
production deployment remains independently authorized.
