import {
  readWorkerRuntimeConfiguration,
  scrubWorkspaceEnvironment,
} from "./configuration.ts";
import { runOneFakeWorkerCycle } from "./worker_runtime.ts";

Deno.test("worker defaults fail closed and strips credentials from workspace children", () => {
  try {
    readWorkerRuntimeConfiguration({ CURAVAULT_CODEX_WORKER_ID: "worker-1" });
  } catch (error) {
    throw error;
  }
  const scrubbed = scrubWorkspaceEnvironment({
    PATH: "/bin",
    OPENAI_API_KEY: "secret",
    GITHUB_TOKEN: "secret",
    DATABASE_URL: "secret",
  });
  if (
    "OPENAI_API_KEY" in scrubbed || "GITHUB_TOKEN" in scrubbed ||
    "DATABASE_URL" in scrubbed
  ) throw new Error("credential leaked to workspace child");
});

Deno.test("deterministic fake worker runs lifecycle without provider network", async () => {
  const previous = { ...Deno.env.toObject() };
  Deno.env.set("CURAVAULT_CODEX_WORKER_ID", "fake-worker");
  Deno.env.set("CURAVAULT_CODEX_FAKE_EXECUTION_ENABLED", "true");
  Deno.env.set("CURAVAULT_CODEX_LIVE_EXECUTION_ENABLED", "false");
  Deno.env.set("CURAVAULT_WORKSPACE_ROOT", await Deno.makeTempDir());
  let completed = false;
  const outcome = await runOneFakeWorkerCycle({
    claim: async () => ({
      jobId: "job-1",
      leaseToken: "lease",
      request: {
        jobId: "job-1",
        repository: "stevebattmanersby/curavult-app",
        baseSha: "a".repeat(40),
        taskPrompt: "untrusted",
        agentsMd: "policy",
        maxRuntimeSeconds: 60,
        maxOutputTokens: 10,
      },
    }),
    complete: async (_job, result) => {
      completed = result.cleanupSucceeded &&
        result.changedPaths[0] === "docs/fake-provider-evidence.md";
    },
    fail: async () => {
      throw new Error("fake provider should not fail");
    },
  });
  if (outcome !== "succeeded" || !completed) {
    throw new Error("fake lifecycle did not complete");
  }
  for (const [key, value] of Object.entries(previous)) Deno.env.set(key, value);
});
