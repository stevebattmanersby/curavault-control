export interface WorkerRuntimeConfiguration {
  workerId: string;
  liveExecutionEnabled: boolean;
  fakeExecutionEnabled: boolean;
  workspaceRoot: string;
}

const truth = (value: string | undefined) => value === "true";

export function readWorkerRuntimeConfiguration(
  env: Record<string, string | undefined> = Deno.env.toObject(),
): WorkerRuntimeConfiguration {
  const workerId = env.CURAVAULT_CODEX_WORKER_ID ?? "";
  if (!/^[A-Za-z0-9_.-]{1,80}$/.test(workerId)) {
    throw new Error("worker_id_invalid");
  }
  const liveExecutionEnabled = truth(
    env.CURAVAULT_CODEX_LIVE_EXECUTION_ENABLED,
  );
  const fakeExecutionEnabled = truth(
    env.CURAVAULT_CODEX_FAKE_EXECUTION_ENABLED,
  );
  if (liveExecutionEnabled && fakeExecutionEnabled) {
    throw new Error("worker_mode_conflict");
  }
  return {
    workerId,
    liveExecutionEnabled,
    fakeExecutionEnabled,
    workspaceRoot: env.CURAVAULT_WORKSPACE_ROOT ?? "/workspaces",
  };
}

/// Workspace subprocesses receive no control-plane, repository, or provider credential.
export function scrubWorkspaceEnvironment(
  env: Record<string, string | undefined> = Deno.env.toObject(),
): Record<string, string> {
  const allowed = ["PATH", "HOME", "LANG", "LC_ALL", "TMPDIR"];
  return Object.fromEntries(
    allowed.flatMap((key) => env[key] ? [[key, env[key]!]] : []),
  );
}
