import {
  CodexExecutionProvider,
  type CodexExecutionRequest,
  type WorkspaceInspection,
} from "../codex_execution_provider.ts";
import { readWorkerRuntimeConfiguration } from "./configuration.ts";
import { FakeCodexTransport } from "./fake_provider.ts";
import { createIsolatedWorkspace } from "./workspace_manager.ts";

export interface ClaimedJob {
  jobId: string;
  leaseToken: string;
  request: CodexExecutionRequest;
}
export interface WorkerControlPlane {
  claim(workerId: string): Promise<ClaimedJob | null>;
  complete(
    job: ClaimedJob,
    result: {
      changedPaths: string[];
      diffSha256: string;
      cleanupSucceeded: boolean;
    },
  ): Promise<void>;
  fail(job: ClaimedJob, code: string): Promise<void>;
}

export async function runOneFakeWorkerCycle(
  control: WorkerControlPlane,
): Promise<"idle" | "succeeded" | "failed"> {
  const config = readWorkerRuntimeConfiguration();
  if (!config.fakeExecutionEnabled || config.liveExecutionEnabled) {
    return "idle";
  }
  const job = await control.claim(config.workerId);
  if (!job) return "idle";
  const workspace = await createIsolatedWorkspace(config.workspaceRoot);
  let cleaned = false;
  try {
    const provider = new CodexExecutionProvider(new FakeCodexTransport());
    const inspection: WorkspaceInspection = {
      repositoryMatched: true,
      baseShaMatched: true,
      remoteUnchanged: true,
      cleanupSucceeded: true,
      changedPaths: ["docs/fake-provider-evidence.md"],
    };
    const result = await provider.start(job.request, inspection);
    cleaned = await workspace.cleanup();
    if (result.status !== "succeeded" || !cleaned) {
      await control.fail(
        job,
        cleaned ? "provider_error" : "workspace_cleanup_failed",
      );
      return "failed";
    }
    await control.complete(job, {
      changedPaths: result.changedPaths,
      diffSha256: "f".repeat(64),
      cleanupSucceeded: true,
    });
    return "succeeded";
  } catch (_) {
    if (!cleaned) cleaned = await workspace.cleanup();
    await control.fail(job, "provider_error");
    return "failed";
  }
}
