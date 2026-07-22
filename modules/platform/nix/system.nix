_: {
  imports = [./common.nix];

  nix = {
    settings = {
      auto-optimise-store = true;

      # let wheel members push unsigned store paths via `nixos-rebuild --target-host`
      trusted-users = ["root" "@wheel"];
    };
    # automatic + retention live in common.nix; only the systemd schedule + persistence here.
    # servers are UTC so monday 12:00 is 4a/5a pacific. the pacific desktop gets
    # it at noon local instead, which is background noise on nvme
    # see SCHEDULE.md
    gc = {
      dates = "Mon 12:00";
      persistent = true;
    };
    optimise.dates = ["Mon 13:00"]; # an hour after gc so they don't fight over the store
  };
}
