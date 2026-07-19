# darwin face of the nix platform module: launchd calendar intervals instead
# of systemd calendars, and macos admins live in `admin`, not `wheel`.
# auto-optimise-store stays off here -- it corrupts the store on macos
# (NixOS/nix#7273); the weekly optimise pass covers it
_: {
  imports = [./common.nix];

  nix = {
    settings.trusted-users = ["root" "@admin"];

    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 3;
        Minute = 0;
      };
      options = "--delete-older-than 7d";
    };

    optimise = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 4;
        Minute = 0;
      };
    };
  };
}
