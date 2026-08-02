{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.autostart;

  # each DE module contributes its own session target here, so a systemd unit
  # bound to `targets` runs under whichever sessions a host actually imports,
  # with no host-level list to keep in sync
  targetsFor = app:
    if app.targets == null
    then cfg.targets
    else app.targets;

  # tray-icon apps race quickshell/plasmashell for org.kde.StatusNotifierWatcher at
  # session start; poll for the name instead of guessing a delay, and fall through
  # after ~15s so a stuck/crashed tray host never blocks the app it's wrapping
  waitForTray = pkgs.writeShellScript "wait-for-tray" ''
    for _ in $(seq 1 150); do
      [ "$(${pkgs.systemd}/bin/busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.kde.StatusNotifierWatcher 2>/dev/null)" = "b true" ] && exit 0
      sleep 0.1
    done
    exit 0
  '';

  mkUnit = name: app: let
    targets = targetsFor app;
  in {
    Unit = {
      Description = "${name} (session autostart)";
      PartOf = targets;
      After = targets;
    };
    Service =
      {ExecStart = app.exec;}
      // lib.optionalAttrs app.tray {ExecStartPre = "${waitForTray}";};
    Install.WantedBy = targets;
  };
in {
  options.my.autostart = {
    targets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "systemd user targets that autostart apps bind to; DE modules append their own session target";
    };

    apps = lib.mkOption {
      default = {};
      description = "apps to launch at session start; each app module registers itself here";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          exec = lib.mkOption {
            type = lib.types.str;
            description = "command to run";
          };
          tray = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "wait for a StatusNotifierWatcher before launching";
          };
          targets = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default = null;
            description = "override the default session targets for this app";
          };
        };
      });
    };
  };

  config.systemd.user.services = lib.mapAttrs mkUnit cfg.apps;
}
