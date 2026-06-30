# arr-stack

\*arr media stack. sonarr, radarr, prowlarr, qbittorrent, sabnzbd, recyclarr.

sonarr/radarr/prowlarr/qbittorrent run inside a wireguard netns via `vpnNamespaces.wg` from `vpn-confinement`. sabnzbd stays in the main ns (no vpn needed for usenet).

```nix
{ modules, ... }: {
  imports = [modules.services.arr-stack.default];
  lab.arrStack = {
    torrentsPath = "/mnt/disk/path/to/torrents";
    nzbPath      = "/mnt/disk/path/to/nzb";
  };
}
```

needs `inputs.vpn-confinement.nixosModules.default` on the host's module list (wired in `flake.nix` for mesa-svc-01).

## options

- `mediaGroup` (default `"media"`) - shared group for file perms
- `torrentsPath`, `nzbPath` (required) - download dirs
- `lanProxy` (default `true`) - DNAT host ports into the netns
- `lanProxyPorts` (default `{sonarr=8989; radarr=7878; prowlarr=9696; qbittorrent=8888;}`)
- `accessibleFrom` (default `["192.168.0.0/16" "10.0.0.0/8"]`) - subnets the netns will return-route to
- `wgMtu` (default `1320`, AirVPN-tuned) - applied via ExecStartPost since VPN-Confinement strips MTU from wg-quick

## gotchas

- namespace name capped at 7 chars by VPN-Confinement (used as the unit + iface suffix); `wg` here
- in-namespace clients hit pg at `config.vpnNamespaces.wg.bridgeAddress`; the postgres module's `allowedCidrs` is set to that /24
- `prowlarr` doesn't accept `environmentFiles` upstream, so the unit is defined here directly
- qbittorrent's `ResumeDataStorageType` is pinned to `Legacy` (`.fastresume` on disk; easier to back up)
- recyclarr runs daily with a fixed quality-profile + custom-format config in `recyclarr.nix`; edit there to change the policy globally
- qbittorrent state (BT_backup, RSS, GeoDB) lives under `siteData/qbittorrent` and isn't nix-managed
- indexer config in prowlarr and download-client config in sonarr/radarr land in postgres
