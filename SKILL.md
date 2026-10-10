---
name: deploy-clash-node
description: Use when a user asks to deploy a self-hosted Clash or Mihomo-compatible proxy node on a server, import existing routing rules, or publish that node as a remote subscription.
---

# Deploy a Clash-compatible node

Complete the requested deployment and return an importable profile or subscription URL. Treat server credentials, node keys, and subscription URLs as secrets. Never put them in repositories, command-line arguments, process logs, or reusable skill files.

## Scope and preparation

Confirm the requested outcome from context: a node, a local Clash profile, existing routing rules, and/or a remote subscription. Do not expose extra ports or publish a subscription unless the user requested that outcome. Before changing the host, check OS, architecture, active listeners, firewall, existing proxy services, and any project deployment instructions. Preserve existing services and configurations. Verify current installation and protocol details against upstream Xray and Mihomo documentation because these can change.

Use an interactive secret prompt or another protected channel for SSH credentials. Check the host key against a known fingerprint when one is available; otherwise record the first observed fingerprint and detect changes on later connections. Avoid temporary scripts that contain passwords or server private keys; remove task-specific temporary files after use.

## Node

For a clean Ubuntu 24.04 x86_64 server, inspect and use [scripts/deploy.sh](scripts/deploy.sh) when the user wants the default VLESS Reality node plus HTTPS subscription. The script stops on occupied ports or existing deployment files. For an existing server or another desired protocol, deploy manually after inspecting its current state.

For a Mihomo-compatible VLESS Reality node, install Xray from its official release or installer, generate a fresh UUID, X25519 key pair, and short ID, and configure a dedicated inbound. Select the port and Reality target only after checking reachability and conflicts. Keep the private key on the server, readable by the service account; place only the public key, UUID, short ID, host, port, SNI, fingerprint, and flow in the client profile. Enable the service and open only the required firewall port.

Run the server's configuration check, verify the service stays active and listens on the expected port, then validate the client YAML with Mihomo. Make one actual request through a temporary local Mihomo proxy and confirm the observed exit IP. A successful YAML parse or open TCP port alone does not prove the node works.

## Existing routing rules

If the user asks to match a current Clash setup, inspect the **runtime configuration** and any profile scripts or extensions, not just the source subscription. Copy the effective rules and groups into the new profile, replace old node references with the new node, and retain the existing `DIRECT`, `REJECT`, group order, and final `MATCH` behavior. Validate that all group choices and rule targets resolve. Do not silently turn a direct-by-default policy into `MATCH,PROXY`. Explain that importing a local profile creates an app-managed copy.

## Remote subscription, when requested

Serve the validated profile over HTTPS at an unguessable path; the URL grants access to node credentials. Never use plain HTTP for this profile. If the server has no domain, check whether a trusted IP-address certificate is currently available. When using a short-lived certificate, configure automatic renewal and reload the HTTPS server after renewal; verify renewal with a dry run. Keep the proxy listener and subscription listener separate unless the existing architecture supports sharing them. Restrict the Web server to the exact subscription path, with other paths returning 404.

Fetch the final URL from outside the server with normal certificate validation. Compare the downloaded bytes or parsed proxy and rule counts with the intended profile. Report the URL, import steps, renewal status, and whether later local file edits will sync automatically. Rotate the URL and node credentials if their contents have been exposed.
