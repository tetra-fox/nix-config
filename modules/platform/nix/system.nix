_: {
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      cores = 0;
      max-jobs = "auto";

      # frees paths mid-build instead of failing with ENOSPC on the small fleet VMs
      min-free = 536870912;
      max-free = 3221225472;

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
