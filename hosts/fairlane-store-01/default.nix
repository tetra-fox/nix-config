{modules, ...}: {
  imports = [
    ./storage.nix

    modules.profiles.server.system

    modules.toolsets.disk.system # smartctl etc for the passthrough drive
    modules.toolsets.hardware.system # lspci, to confirm the guest sees the passthrough controller
    modules.toolsets.observe.system # iostat/iotop for disk-side latency
  ];

  lab = {
    site = {
      hostIp = "192.168.10.100";
      internalIp = "10.10.0.100";
      proxmoxParent = "pooltoy"; # the media passthrough disk lives on pooltoy
    };
  };

  system.stateVersion = "26.11";
}
