# nix daemon settings shared by the linux (system.nix) and darwin (darwin.nix)
# faces of this module; only the gc/optimise schedule and the admin group differ
# per platform, so those stay in the platform files
_: {
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      cores = 0;
      max-jobs = "auto";

      # frees paths mid-build instead of failing with ENOSPC on the small fleet VMs
      min-free = 536870912;
      max-free = 3221225472;
    };

    # shared gc retention + optimise pass; only the schedule (systemd dates vs launchd
    # interval) differs per platform
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
    optimise.automatic = true;
  };
}
