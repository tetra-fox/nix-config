{ pkgs, ... }:

{
  xdg.configFile."snappy-switcher/config.ini".text = builtins.readFile ./snappy-switcher.ini;

  wayland.windowManager.hyprland.settings = {
    bind = [
      "L_ALT,TAB,exec,${pkgs.snappy-switcher}/bin/snappy-switcher next"
      "L_ALT&L_SHIFT,TAB,exec,${pkgs.snappy-switcher}/bin/snappy-switcher prev"
    ];

    exec-once = [
      "${pkgs.snappy-switcher}/bin/snappy-switcher --daemon"
    ];
  };
}
