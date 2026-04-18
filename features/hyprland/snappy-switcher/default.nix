{ pkgs, ... }:

{
  xdg.configFile."snappy-switcher/config.ini".text = builtins.readFile ./snappy-switcher.ini;

  wayland.windowManager.hyprland.settings = {
    # locked = fires even when an app has grabbed keyboard input (e.g. Minecraft via LWJGL)
    bindl = [
      "L_ALT,TAB,exec,${pkgs.snappy-switcher}/bin/snappy-switcher next"
      "L_ALT&L_SHIFT,TAB,exec,${pkgs.snappy-switcher}/bin/snappy-switcher prev"
    ];

    exec-once = [
      "app2unit --${pkgs.snappy-switcher}/bin/snappy-switcher --daemon"
    ];
  };
}
