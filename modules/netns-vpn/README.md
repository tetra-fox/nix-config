# netns-vpn

vpn-isolated network namespace + a wireguard interface inside it. services that need vpn isolation reference this via `NetworkNamespacePath=/var/run/netns/vpn` (exported as `_module.args.netnsPath`).

## usage

```nix
{ modules, ... }: {
  imports = [modules.netns-vpn.system];
}
```

in a service that should run inside the netns:

```nix
{ netnsPath, netns, ... }: {
  systemd.services.myapp = {
    after    = ["wg-vpn.service"];
    requires = ["wg-vpn.service"];
    bindsTo  = ["wg-vpn.service"];      # stop within seconds if vpn drops
    serviceConfig = {
      NetworkNamespacePath = netnsPath;
      BindReadOnlyPaths    = ["/etc/netns/${netns}/resolv.conf:/etc/resolv.conf"];
    };
  };
}
```

## options (`lab.netnsVpn.*`)

| option | type | default | description |
|---|---|---|---|
| `mtu` | int | `1320` | wg interface MTU. AirVPN=1320, Mullvad=1280 |
| `secretPrefix` | str | `"arr"` | sops path prefix; expects `<prefix>/wg_{private_key,peer_public_key,preshared_key,peer_endpoint,address}` |

## exported via `_module.args`

| arg | value | purpose |
|---|---|---|
| `netns` | `"vpn"` | netns name |
| `netnsPath` | `/var/run/netns/vpn` | for systemd `NetworkNamespacePath=` |
| `hostVethIp` | `10.200.200.1` | host-side veth; reach the netns from the host, or reach the host from inside the netns |
| `nsVethIp` | `10.200.200.2` | netns-side veth |

## provides

- `netns-vpn.service` (oneshot creating the netns + veth bridge to main ns)
- `wg-vpn.service` (oneshot creating wg0 in main ns, then moving it into vpn ns)
- the five `<secretPrefix>/wg_*` sops secrets
- exported `_module.args` so consumers don't have to thread these names through their own arg lists

## expects

- the actual wg secret values (in `secrets/<host>.yaml`)
- consumers' systemd binding to `wg-vpn.service` (fail-closed pattern lives in the consumer module)

## design notes

- wg0 is created in the **main ns first**, then moved into the vpn ns. the udp socket binds in main ns (so wg traffic routes out the host normally) while the iface itself lives in vpn ns. the other way around forces wg traffic to also enter the vpn - chicken/egg
- script logic lives in `netns-{up,down}.sh` and `wg-{up,down}.sh`; symbolic names pass via env vars so the .sh files have no nix interpolation noise and can be tested standalone
- sops secrets are loaded via systemd `LoadCredential` so they don't end up in `/proc/<pid>/environ`. wg-up.sh uses `$(< file)` not `read -r`, which fails under `set -e` on files without trailing newlines
