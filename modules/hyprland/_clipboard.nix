{
  pkgs,
  main_mod,
  ...
}: {
  home.packages = [pkgs.wl-clipboard];

  services = {
    clipse.enable = true;
    wl-clip-persist = {
      enable = true;
      systemdTargets = "wayland-session@hyprland.desktop.target";
    };
  };

  wayland.windowManager.hyprland.extraLuaFiles.clipboard.content =
    pkgs.replaceVars ./_clipboard.lua {inherit main_mod;};
}
