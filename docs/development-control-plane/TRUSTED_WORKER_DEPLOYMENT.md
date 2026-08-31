# Trusted Worker VM Deployment

## Status

Code and host artifacts are ready for review. **HOST NOT DEPLOYED.** Do not
enable Codex provider or worker live execution from this guide.

## Provisioning sequence

1. Create one dedicated supported Ubuntu LTS x86_64 VM. Restrict SSH port 22 to
   the Owner's management CIDR before first login; use key-only authentication.
2. Apply the reviewed `infra/trusted-worker/cloud-init.yaml`; it intentionally
   does not enable UFW because a blanket SSH allow rule would be unsafe. Before
   enabling UFW, use the cloud console/private-management network to run
   `ufw allow from <OWNER_MANAGEMENT_CIDR> to any port 22 proto tcp`, then run
   `ufw --force enable`. Verify no public PostgreSQL, Docker remote API, web
   server, or unrelated workload exists.
3. Install the reviewed image and files under `/opt/curavault-trusted-worker`.
4. Create `/etc/curavault-trusted-worker/worker.env` as root, mode `0600`.
   Required externally supplied values are worker DB credential, GitHub
   contents-read credential, and OpenAI key. Keep both live/fake gates false.
5. Create `/var/lib/curavault-trusted-worker/workspaces` on a dedicated
   filesystem or volume with a 2 GB per-workspace project quota, owned only by
   the non-root container UID. The sandbox also has a 1 GB maximum file size
   and a 30-minute host watchdog. Install the systemd unit and log rotation
   file.
6. Run `verify-host-contract.sh`, inspect Docker sandbox settings, and record
   safe evidence. Do not set verification flags until this host evidence exists.
   The Phase 5 control worker has no Docker socket; live execution remains
   disabled until a separately reviewed host-local sandbox supervisor can call
   the fixed runner without disclosing the Docker API to the worker.

## Credential procedures

Use a GitHub App preferred, or a short-lived fine-grained token scoped to only
`stevebattmanersby/curavult-app`, `Contents: Read-only`. It must not receive
write, pull-request, workflow, administration, environment, or deployment
permission. Provision a dedicated `curavault_codex_worker` database login
credential externally. It must execute worker RPCs only; confirm direct table
reads/writes, Owner RPCs, grants, and role changes fail. An OpenAI credential
is injected into the control worker only; do not mark it verified without an
explicitly authorized non-execution credential check or later smoke test.

## Operations and recovery

Use `systemctl stop curavault-trusted-worker` as the third kill switch after
the DB provider flag and worker live gate. For an incident: disable provider,
disable live gate, stop service, revoke OpenAI/GitHub credentials, rotate the
worker password, inspect durable jobs, retain safe audit records, and purge
workspaces. The VM is disposable: rebuild from cloud-init, image, externally
provisioned secrets, and host validation; never restore old workspaces.

Disk guard: alert at 70% workspace volume use and remove orphaned failed
workspaces older than 24 hours only after recording cleanup evidence. Alert on
worker down, stale heartbeat, long-running job, repeated failure, cleanup
failure, stale lease, and disk threshold. Initial notification delivery may be
manual until a reviewed monitoring provider is connected.
