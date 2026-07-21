_: {
  imports = [./common.nix];

  nix = {
    settings = {
      auto-optimise-store = true;

      # let wheel members push unsigned store paths via `nixos-rebuild --target-host`
      trusted-users = ["root" "@wheel"];
    };
    # automatic + retention live in common.nix; only the systemd schedule + persistence here
    gc = {
      dates = "weekly";
      persistent = true;
    };
    optimise.dates = ["weekly"];
  };
}
