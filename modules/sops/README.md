# sops

sops-nix integration. each host imports this and points it at the host's encrypted yaml.

## usage

```nix
{ modules, ... }: {
  imports = [modules.sops.system];
  lab.sops.secretsFile = ../../secrets/myhost.yaml;
}
```

other modules then declare their secrets near consumption:

```nix
sops.secrets."myapp/api_key" = {};
sops.templates."myapp.env".content = ''
  API_KEY=${config.sops.placeholder."myapp/api_key"}
'';
```

## options (`lab.sops.*`)

| option | type | default | description |
|---|---|---|---|
| `secretsFile` | `nullOr path` | `null` | path to the host's encrypted sops yaml |

## exported via `_module.args`

| arg | type | description |
|---|---|---|
| `siteEnvFile` | `str -> list path` | helper for systemd `EnvironmentFile`/oci-containers `environmentFiles`. returns `[ config.sops.templates.<name>.path ]` |

## provides

- `sops.defaultSopsFile` pointing at the host's yaml
- `age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"]` so decryption uses the host's existing ssh key (no separate age key to manage)
- the `siteEnvFile` helper exported via `_module.args`

## expects

- the encrypted yaml itself (path-pointed by `secretsFile`)
- which secrets get declared and where (each consumer module declares its own; this module just wires the plumbing)

## design notes

- first deploy on a fresh host fails to decrypt until the host's age key is added to `.sops.yaml`. services that need secrets fail to start with sops-nix activation errors. workflow is in DEPLOY.md
- stack modules (`arr-stack`, `netns-vpn`, `monitoring`, `caddy`, etc.) declare their own secrets/templates. this module is just the wiring + the `siteEnvFile` helper
