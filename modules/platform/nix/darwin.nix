# auto-optimise-store stays off here, it corrupts the store on macos
# (NixOS/nix#7273). the weekly optimise pass covers it
_: {
  imports = [./common.nix];

  nix = {
    # root is already in the nix-darwin default
    settings.trusted-users = ["@admin"];

    # colmena builds fleet closures on the deployer. stock config: a custom one changes
    # the VM image derivation, which nothing substitutes
    linux-builder.enable = true;

    # the mac keeps pacific time. see SCHEDULE.md
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
      interval = {
        Weekday = 0;
        Hour = 4;
        Minute = 0;
      };
    };

    optimise.interval = {
      Weekday = 0;
      Hour = 5;
      Minute = 0;
    };
  };
}
