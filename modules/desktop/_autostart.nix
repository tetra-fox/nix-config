{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.autostart;

  # each DE module adds its session target, so units run under whichever sessions
  # the host imports
  targetsFor = app:
    if app.targets == null
    then cfg.targets
    else app.targets;

  # tray apps race the tray host for StatusNotifierWatcher at session start.
  # gives up after ~15s so a dead tray host doesn't block the app
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
      {
        ExecStart = app.exec;
        # vrcx and discord ignore SIGTERM, and a session target can't restart until its
        # units finish stopping, so a relogin inside the default 90s timeout fails.
        # TODO: drop once both exit on SIGTERM
        TimeoutStopSec = 5;
      }
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
