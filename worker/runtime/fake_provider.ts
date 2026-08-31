import type {
  CodexProviderResult,
  CodexTransport,
} from "../codex_execution_provider.ts";

/// Deterministic only. It never contacts OpenAI and has no credential surface.
export class FakeCodexTransport implements CodexTransport {
  async start(): Promise<CodexProviderResult> {
    return {
      providerReference: "fake-provider-run",
      status: "succeeded",
      summary: "Fake provider completed the isolated dry run.",
      changedPaths: ["docs/fake-provider-evidence.md"],
      testsSummary: "fake validation passed",
      analyzerSummary: "not run in fake mode",
    };
  }
  async cancel(): Promise<void> {}
}
