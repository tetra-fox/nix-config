{lib, ...}: {
  imports = [./common.nix];

  nix = {
    settings = {
      auto-optimise-store = true;

      # wheel pushes unsigned paths on remote deploys
      trusted-users = ["root" "@wheel"];
    };
    # see SCHEDULE.md
    gc = {
      dates = lib.mkDefault "Mon 12:00";
      persistent = true;
    };
    optimise.dates = ["Mon 13:00"]; # after gc
  };
}
