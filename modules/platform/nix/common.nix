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
      # nurpkgs serves tetra-nurpkgs. both deployers build server closures, so not hara only
      substituters = [
        "https://nix-community.cachix.org"
        "https://tetra-fox-nurpkgs.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "tetra-fox-nurpkgs.cachix.org-1:UPmzw8DqV1QLd7YC58exrtKuPFo0JdmO+ywu34+zHiE="
      ];
    };

    # schedules live in the platform files
    optimise.automatic = true;
  };
}
