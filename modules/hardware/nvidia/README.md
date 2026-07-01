# nvidia

nvidia driver bundle (kernel module + userland + xserver video driver). optional prometheus exporter that scrapes the GPU and contributes a community dashboard onto the observability bus.

```nix
{ modules, ... }: {
  imports = [modules.hardware.nvidia.system];
  lab.nvidia.exporter.enable = true;
}
```

server hosts (anything importing `modules.profiles.server.system`) flip `hardware.nvidia.powerManagement.enable = false` - servers don't suspend.

pascal-and-older GPUs (GTX 10xx, 9xx) need the legacy 580 driver and don't support open kernel modules. override in a host quirk:

```nix
hardware.nvidia = {
  open = false;
  package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
};
```

see `quirks/mesa-svc-01/gtx-1080.nix`.

## options

- `lab.nvidia.exporter.enable` (default `false`) - run nvidia-gpu-exporter, contribute scrape job + dashboard 14574
- `lab.nvidia.exporter.port` (default `9835`) - upstream default
- `lab.nvidia.exporter.openFirewall` (default `false`) - local prometheus doesn't need it; flip on for a remote scrape

## gotchas

- `services.xserver.videoDrivers = ["nvidia"]` is metadata that pulls in the driver package; it doesn't enable xserver itself, so it's safe on headless servers
- `hardware.nvidia.{open,powerManagement}` are `mkDefault` so quirks (legacy GPUs) and the server profile can flip them off without `mkForce`
