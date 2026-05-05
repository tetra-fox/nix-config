# nvidia

nvidia driver bundle (kernel module + userland + xserver video driver). includes an optional prometheus exporter that scrapes the GPU and contributes a community dashboard onto the observability bus.

## usage

```nix
{ modules, ... }: {
  imports = [modules.nvidia.system];

  lab.nvidia.exporter.enable = true;   # gpu metrics + dashboard
}
```

server hosts (anything importing `modules.profiles.server.system`) get `hardware.nvidia.powerManagement.enable = false` automatically - servers don't suspend.

pascal-and-older GPUs (GTX 10xx, 9xx) need the legacy 580 driver branch and don't support open kernel modules - override in a host quirk:

```nix
hardware.nvidia = {
  open = false;
  package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
};
```

see `quirks/mesa-svc-01/gtx-1080.nix` for an example.

## options (`lab.nvidia.*`)

| option | type | default | description |
| --- | --- | --- | --- |
| `exporter.enable` | bool | `false` | run prometheus-nvidia-gpu-exporter and contribute scrape job + community dashboard (id 14574) |
| `exporter.port` | port | `9835` | exporter listen port (upstream default) |
| `exporter.openFirewall` | bool | `false` | open the exporter port in the firewall; off by default since the local prometheus scrape doesn't need it |

## provides

- nvidia kernel module + userland via `hardware.nvidia.{open,modesetting,powerManagement,nvidiaSettings}` and `hardware.graphics.enable`
- `services.xserver.videoDrivers = ["nvidia"]` - metadata that pulls in the driver package; does not enable xserver itself, so safe on headless servers
- prometheus-nvidia-gpu-exporter on `:9835` + scrape config + dashboard 14574 (when `exporter.enable`); contributions are silent on hosts that don't import the monitoring module

## design notes

- `hardware.nvidia.{open,powerManagement}` are `mkDefault`-wrapped so per-host quirks (legacy GPUs) and the server profile can flip them off without `mkForce`
- exporter wiring follows the same shape as docker's cadvisor: opt-in option that pushes a scrape job to `services.prometheus.scrapeConfigs` and a dashboard descriptor to `lab.observability.communityDashboards`, both no-ops if no monitoring consumer reads them
