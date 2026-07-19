_: {
  imports = [./common.nix];

  nix = {
    settings = {
      auto-optimise-store = true;

      # let wheel members push unsigned store paths via `nixos-rebuild --target-host`
      trusted-users = ["root" "@wheel"];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      persistent = true;
      options = "--delete-older-than 7d";
    };
    optimise = {
      automatic = true;
      dates = ["weekly"];
    };
  };
}
