{...}: {
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      cores = 0; # use all cores per build
      max-jobs = "auto"; # parallel derivations
    };
    gc = {
      automatic = true;
      dates = "weekly";
      persistent = true;
      options = "--delete-generations +8"; # keep last 8 generations
    };
  };
}
