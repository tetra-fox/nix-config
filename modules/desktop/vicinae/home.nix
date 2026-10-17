{
  config,
  pkgs,
  lib,
  ...
}: let
  targets = config.my.autostart.targets;
in {
  imports = [../_autostart.nix];

  programs.vicinae = {
    systemd.enable = true;
    enable = true;
    settings = {
      close_on_focus_loss = false;
      pop_to_root_on_close = true;
      escape_key_behavior = "";
      font = {
        rendering = "qt";
      };
      launcher_window = {
        rounding = 0;
        client_side_decorations = {
          border_width = 1;
          shadow_size = 12;
        };
      };
      providers.applications.preferences = {
        defaultAction = "focus";
        launchPrefix = "${lib.getExe pkgs.app2unit} --";
      };
      core.entrypoints = {
        sponsor.enabled = false;
      };
    };
  };

  # hm's unit takes one systemd.target; kept over a my.autostart app for its restart
  # triggers, so rebind it to every session target
  systemd.user.services.vicinae = {
    Unit = {
      After = lib.mkForce targets;
      PartOf = lib.mkForce targets;
    };
    Install.WantedBy = lib.mkForce targets;
  };
}
