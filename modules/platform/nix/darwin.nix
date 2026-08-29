# darwin face of the nix platform module: launchd calendar intervals instead
# of systemd calendars, macos admins live in `admin`, not `wheel`, and the linux
# builder a mac needs to build fleet closures at all.
# auto-optimise-store stays off here -- it corrupts the store on macos
# (NixOS/nix#7273); the weekly optimise pass covers it
_: {
  imports = [./common.nix];

  nix = {
    settings.trusted-users = ["root" "@admin"];

    # colmena deploys with deployment.buildOnTarget = false (flake/colmena.nix), so the
    # machine running the deploy builds every host's closure. that has to stay: the fleet
    # VMs are too small to build their own, the edges are 1 core / 900M and
    # lab.caddy.package is an xcaddy go build no cache carries. a mac can't build linux
    # derivations, so without this `colmena apply` fails with "a 'x86_64-linux' with
    # features {} is required to build". _rebuild.sh solves the same problem the other
    # way, by building on the target.
    #
    # stock settings on purpose: nix.linux-builder.config changes the VM image derivation,
    # which nothing substitutes, so customizing it would need a linux builder to build the
    # linux builder. defaults are 3G ram, 20G disk, 1 core. tune it once this runs.
    linux-builder.enable = true;

    # automatic + retention live in common.nix; only the launchd schedule here.
    # the mac keeps local (pacific) time, so sunday 4a is inside the sleep window
    # see SCHEDULE.md
    gc.interval = {
      Weekday = 0;
      Hour = 4;
      Minute = 0;
    };

    optimise.interval = {
      Weekday = 0;
      Hour = 5;
      Minute = 0;
    };
  };
}
