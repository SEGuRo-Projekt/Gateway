# Service customization
This section covers how to customize gateway services to fit your deployment,

## Table of Contents
- [TimeServers](#timeservers)
- [Automatic Updates](#automatic-updates)
  - [Enabling](#enabling)
  - [Private repositories & deploy keys](#private-repositories--deploy-keys)
- [Heartbeat Sender](#heartbeat-sender)

## TimeServers
In certain network configurations, gateways may need to synchronize with custom time servers (e.g., NTP servers) to keep their clocks in sync and ensure certificate validity. This can be configured via `timesyncd`, for example:

```nix
services.timesyncd.servers = [
  "ntp1.rwth-aachen.de"
  "ntp2.rwth-aachen.de"
];
```
## Automatic Updates

Gateways can be configured to automatically pull and apply updates from Git
repositories via NixOS's `system.autoUpgrade` mechanism. This is disabled by
default and must be explicitly opted into.

### Enabling

```nix
{ inputs, ... }:
{
  imports = [ inputs.seguro-gateway.nixosModules.auto-update ];

  services.gateway.autoUpgrade = {
    enable = true;
    flake = "git+ssh://git@<my-git-url>?ref=<branch>#<attribute-path>";
    dates = "02:00";              # pull timer
    randomizedDelaySec = "5min";  # spread load on the repo for bigger fleets
  };
}
```

- **`flake`** must be a full flake reference, including the `?ref=<branch>`
  query parameter (selecting which branch this device tracks) and the
  `#<attribute-path>` fragment (matching a key under `nixosConfigurations` in
  `flake.nix`).
- **`dates`** accepts any systemd calendar expression — see
  [`systemd.time(7)`](https://www.freedesktop.org/software/systemd/man/latest/systemd.time.html)
  for the full syntax (e.g. `"*:0/5"` for every 5 minutes, useful when
  debugging).
- The gateway checks for updates on this schedule; if the target commit is
  unchanged since the last run, the rebuild is a fast no-op.

### Private repositories & deploy keys

For security or privacy concerns, use case specific gateway configurations may live in private repositories, requiring SSH credentials to fetch it. We recommend using a read-only
[deploy key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys)
per repository, encrypted at rest with [agenix](https://github.com/ryantm/agenix)
and decrypted on-device at activation time.

Setting this up (generating the deploy key, encrypting it, and wiring the
decrypted secret into place) follows the standard agenix workflow — see the
[agenix README](https://github.com/ryantm/agenix#tutorial) for the general
mechanism.
Note: Fleet devices can use a shared decryption identity provisioned at flash time rather than per-device host keys, since individual host keys aren't known ahead of deployment. This simplifies the rollout procedure considerably, as devices don't need to be booted before deployment. However, as the identity is shared, there is no way to selectively revoke a single compromised device's decryption access, even when rotating the shared deploy key. Hence, this is **not recommended** for deployments where the Gateway configuration contains sensitive or security-relevant information or data.

## Heartbeat Sender

The Heartbeat-Sender periodically sends status information from the gateway to indicate that it is online and healthy. Depending on your deployment it may be worth adjusting how frequently heartbeat signals are sent.

```nix
systemd.services.seguro-heartbeat-sender = {
    startAt = lib.mkForce "*:*:0/30"; # Run every 30-seconds

};
```
