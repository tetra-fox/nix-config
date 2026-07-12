{
  lib,
  pkgs,
  ...
}: {
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 8;
        consoleMode = "max";
        memtest86.enable = true;
        edk2-uefi-shell = {
          enable = true;
          sortKey = "z_edk2-uefi-shell";
        };
      };
    };
    # default so modules with a kernel constraint (zfs) can pick something older
    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
  };
}
