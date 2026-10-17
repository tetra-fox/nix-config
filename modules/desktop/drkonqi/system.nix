{
  config,
  lib,
  pkgs,
  ...
}: {
  # crash dialog for kde apps outside plasma. plasma6.nix wires the same two lines
  config = lib.mkIf (!config.services.desktopManager.plasma6.enable) {
    systemd.packages = [pkgs.kdePackages.drkonqi];
    systemd.services."drkonqi-coredump-processor@".wantedBy = ["systemd-coredump@.service"];
  };
}
