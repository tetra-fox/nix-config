{...}: {
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      persistent = true;
      options = "--delete-generations +8"; # keep last 8 generations
    };
  };
}
