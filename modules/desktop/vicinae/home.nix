{
  pkgs,
  lib,
  ...
}: {
  programs.vicinae = {
    systemd = {
      enable = true;
      target = "wayland-session@hyprland.desktop.target";
    };
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
}
