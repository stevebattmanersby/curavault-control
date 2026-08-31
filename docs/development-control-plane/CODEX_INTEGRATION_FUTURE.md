# Future Codex Integration Boundary

The proposed future path is: Control Site task -> server-side dispatcher -> execution policy validation -> isolated Codex worktree -> GitHub pull request -> CI -> architecture/security review -> explicit approval -> separately authorized merge or release.

Phase 2 implements only the first two durable records in this shape: a server-side policy decision and deterministic mock lifecycle evidence. It does not call Codex, OpenAI, GitHub, a shell, CI, or a deployment system. Its mock-only provider/mode schema is database-enforced. A locked-down, audited database configuration row defaults to disabled and has no authenticated write path.

A future real provider remains intentionally unimplemented. Browser clients must never receive execution credentials, agents must not bypass repository `AGENTS.md` rules, and stored task/prompt content must be treated as untrusted administrative input rather than system instructions. High and critical work must never auto-merge, and production deployment remains independently authorized. Any real-provider proposal must add separate credential isolation, trusted server-side dispatch, explicit provider and repository allow-lists, asynchronous heartbeat/timeout handling, failure recovery, an architecture review, and a security review before it can be considered.
