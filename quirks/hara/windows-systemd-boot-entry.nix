_: {
  boot.loader.systemd-boot.windows = {
    "windows" = let
      boot-drive = "FS0"; # find with map -c and ls EFI
    in {
      title = "Window Evelyn";
      efiDeviceHandle = boot-drive;
      sortKey = "y_windows";
    };
  };
}
