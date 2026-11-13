_: {
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      cores = 0;
      max-jobs = "auto";

      # gc mid-build instead of ENOSPC on the small fleet VMs
      min-free = 536870912;
      max-free = 3221225472;

      # only the nixpkgs entry the flake pins, no fetching the global registry
      flake-registry = "";

      # nix-community serves nixpkgs-xr, sops-install-secrets and the home-manager manual,
      # tetra-fox serves tetra-nurpkgs and reseek. both deployers build server closures, so not
      # hara only
      substituters = [
        "https://nix-community.cachix.org"
        "https://tetra-fox.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "tetra-fox.cachix.org-1:l70MnHbfeZm2unwKH47I42/imLanZMMSxJbqoS0FvEs="
      ];
    };

    # schedules live in the platform files
    optimise.automatic = true;
  };
}
