_: {
  imports = [./common.nix];

  nix = {
    settings = {
      auto-optimise-store = true;

      # wheel pushes unsigned paths on remote deploys. root is already in the nixpkgs default
      trusted-users = ["@wheel"];
    };
    # after nh-clean. see SCHEDULE.md
    optimise.dates = ["Mon 13:00"];

    # flakes only, NIX_PATH gets nixpkgs from the flake registry
    channel.enable = false;
  };
}
