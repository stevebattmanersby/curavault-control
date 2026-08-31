# CuraVault Trusted Worker Host

This directory defines the initial dedicated Ubuntu LTS x86_64 VM layout. It is
not a deployment and contains no host address, token, password, or private key.
The VM runs only the non-root control worker and creates one disposable Docker
sandbox per job. It is not a web host, database host, or patient-data host.

Deploy only after review: create a dedicated VM, restrict SSH to the Owner's
management CIDR, apply `cloud-init.yaml`, then enable UFW only after verifying
the source-restricted SSH rule through the cloud console or private management
network. Copy the reviewed repository/image, create root-owned `/etc/curavault-trusted-worker/worker.env`
with mode `0600`, then install and enable the systemd unit. Do not set either
live gate true. Neither the control worker nor the sandbox receives a Docker
socket. Before real execution is enabled, a separately reviewed, host-local
sandbox-supervisor boundary must invoke the fixed sandbox runner without
exposing the Docker API to the worker.

Run `scripts/verify-host-contract.sh` on the host after Docker installation.
It verifies the no-network sandbox contract without credentials or a live API.
Each workspace must be created on the dedicated quota-controlled filesystem;
the runner applies a 30-minute watchdog and a 1 GB maximum-file limit as a
second containment layer.
The approved control-plane egress destinations are Supabase/PostgreSQL, GitHub
read access, and OpenAI Responses. SaaS IP ranges are not treated as stable;
production requires an FQDN-aware egress proxy/firewall before live enablement.
