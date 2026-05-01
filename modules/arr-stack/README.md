# arr-stack

*arr media stack. sonarr, radarr, prowlarr, flaresolverr, qbittorrent, sabnzbd, and recyclarr.

sonarr/radarr/prowlarr/qbittorrent live inside a wireguard network namespace (via `lab.netnsVpn`) -- sabnzbd stays in the main ns because there's no need for a vpn on usenet.

## usage

```nix
{ modules, ... }: {
  imports = [
    modules.netns-vpn.system
    modules.arr-stack.default
  ];

  lab.arrStack = {
    torrentsPath = "/mnt/disk/path/to/torrents";
    nzbPath      = "/mnt/disk/path/to/nzb";
  };
}
```

## options (`lab.arrStack.*`)

| option | type | default | description |
|---|---|---|---|
| `mediaGroup` | str | `"media"` | shared group for services for file permissions |
| `torrentsPath` | str | (required) | qBittorrent download directory |
| `nzbPath` | str | (required) | sabnzbd download directory |
| `lanProxy` | bool | `true` | socat LAN proxies forwarding `host:<arr-port>` -> `netns:<port>`. |
| `lanProxyPorts` | `attrsOf port` | `{ sonarr=8989; radarr=7878; prowlarr=9696; qbittorrent=8888; }` | host -> netns port forwards. sabnzbd is omitted (lives in main ns). |

## provides

- `services.{sonarr,radarr,prowlarr,qbittorrent,sabnzbd,flaresolverr}`
- `arr` postgres role owning per-app `<app>-main` and `<app>-log` dbs (declared via `lab.postgres.roles.arr`)
- sops secrets `apps/{sonarr,radarr,sabnzbd_*}_api_key`
- sops env templates rendering `<APP>__POSTGRES__*` and `<APP>__AUTH__APIKEY`
- the `media` group, shared by all stack services for file permissions
- systemd binding: *arr units `requires` wg-vpn + the pg-password oneshot (fail closed; never start with vpn down or unset password)
- LAN socat proxy units (one per port in `lanProxyPorts`) so direct browser access works without going through the netns (this will be removed at a later date, when i can get authentik working properly)
- recyclarr running on a daily timer with an opinionated config (`recyclarr.nix`) that wires sonarr+radarr to a `best_recyclarr` quality profile and a custom-format scoring table (DV/HDR boosts, AV1/x265/upscaled/etc. negative-scored). intent: identical recyclarr policy on every host that imports `arr-stack`. edit `recyclarr.nix` to change the policy globally.

## expects

- `torrentsPath` / `nzbPath` (filesystem-specific)
- anything qbittorrent-state related (BT_backup, RSS, GeoDB) - lives under `siteData/qbittorrent` and is not nix-managed
- indexer config in prowlarr, download client config in sonarr/radarr; this gets written to the postgres databases

## design notes

- `arr-stack` depends on the `netns-vpn` module; **both must be imported** at the host level. `arr-stack` references the `netns-vpn` `_module.args` (`netnsPath`, `hostVethIp`, etc.)
- *arr binaries inside the netns reach host-side postgres at `hostVethIp` (the host-side veth IP, currently `10.200.200.1`). The postgres module's `allowedCidrs` gets `10.200.200.0/24` contributed automatically
- prowlarr's nixos module hardcodes `DynamicUser=true` with a bind-mounted `StateDirectory`; we override to a static `prowlarr` user in the media group so its data dir has predictable ownership consistent with the rest of the stack
- qbittorrent's `ResumeDataStorageType` is pinned to `Legacy` (`.fastresume` files on disk, predictable + easy to back up)
