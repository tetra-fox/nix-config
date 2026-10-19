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
    };

    # schedules live in the platform files
    optimise.automatic = true;
  };
}
