# sops

sops-nix wiring. each host imports this and points it at its encrypted yaml. decryption uses the host's existing `ssh_host_ed25519_key` (no separate age key to manage).

```nix
{ modules, ... }: {
  imports = [modules.platform.sops.system];
  lab.sops.secretsFile = ../../secrets/myhost.yaml;
}
```

other modules declare secrets near their consumer:

```nix
sops.secrets."myapp/api_key" = {};
sops.templates."myapp.env".content = ''
  API_KEY=${config.sops.placeholder."myapp/api_key"}
'';
```

## options

- `lab.sops.secretsFile` (nullable path) - the encrypted yaml for this host

## exported via `_module.args`

- `siteEnvFile :: str -> [path]` - helper for systemd `EnvironmentFile` / oci-containers `environmentFiles`. returns `[ config.sops.templates.<name>.path ]`

## gotchas

- first deploy on a fresh host fails to decrypt until the host's age key is added to `.sops.yaml`. services that need secrets fail to start with sops-nix activation errors
