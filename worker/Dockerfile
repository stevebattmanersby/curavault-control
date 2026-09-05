FROM denoland/deno:2.5.6
RUN mkdir -p /workspaces && chown 65532:65532 /workspaces
WORKDIR /app
COPY --chown=65532:65532 worker /app/worker
USER 65532:65532
ENV CURAVAULT_CODEX_LIVE_EXECUTION_ENABLED=false CURAVAULT_CODEX_FAKE_EXECUTION_ENABLED=false CURAVAULT_WORKSPACE_ROOT=/workspaces
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD deno eval 'Deno.exit(0)'
CMD ["run", "--allow-env=CURAVAULT_CODEX_WORKER_ID,CURAVAULT_CODEX_LIVE_EXECUTION_ENABLED,CURAVAULT_CODEX_FAKE_EXECUTION_ENABLED,CURAVAULT_WORKSPACE_ROOT", "worker/runtime/worker_runtime.ts"]
