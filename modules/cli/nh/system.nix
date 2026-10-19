{lib, ...}: {
  programs.nh = {
    enable = true;
    # replaces nix.gc, nixpkgs warns when both run. the timer is persistent. see SCHEDULE.md
    clean = {
      enable = true;
      dates = lib.mkDefault "Mon 12:00";
      extraArgs = lib.mkDefault "--keep-since 7d";
    };
  };
}
