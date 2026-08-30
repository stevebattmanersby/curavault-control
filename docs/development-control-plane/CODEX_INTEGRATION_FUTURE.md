# Future Codex Integration Boundary

The proposed future path is: Control Site task -> server-side dispatcher -> execution policy validation -> isolated Codex worktree -> GitHub pull request -> CI -> architecture/security review -> explicit approval -> separately authorized merge or release.

This is intentionally not implemented. Browser clients must never receive execution credentials, agents must not bypass repository `AGENTS.md` rules, and stored task/prompt content must be treated as untrusted administrative input rather than system instructions. High and critical work must never auto-merge, and production deployment remains independently authorized.
