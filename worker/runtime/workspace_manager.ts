import { scrubWorkspaceEnvironment } from "./configuration.ts";

export interface IsolatedWorkspace {
  path: string;
  cleanup(): Promise<boolean>;
}

export async function createIsolatedWorkspace(
  root: string,
): Promise<IsolatedWorkspace> {
  const path = await Deno.makeTempDir({
    dir: root,
    prefix: "curavault-codex-",
  });
  return {
    path,
    async cleanup() {
      try {
        await Deno.remove(path, { recursive: true });
        return true;
      } catch (_) {
        return false;
      }
    },
  };
}

export function workspaceCommand(command: string, args: string[], cwd: string) {
  if (!new Set(["git", "dart", "flutter"]).has(command)) {
    throw new Error("command_not_allowed");
  }
  return new Deno.Command(command, {
    args,
    cwd,
    env: scrubWorkspaceEnvironment(),
    clearEnv: true,
  });
}
