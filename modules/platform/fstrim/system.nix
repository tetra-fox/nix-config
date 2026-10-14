{lib, ...}: {
  services.fstrim = {
    enable = true;
    # after gc and optimise free blocks. see SCHEDULE.md
    interval = lib.mkDefault "Mon 14:00";
  };
}
