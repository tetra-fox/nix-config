{ pkgs, ... }:

{
  xdg.configFile."snappy-switcher/config.ini".text = builtins.readFile ./snappy-switcher.ini;

  wayland.windowManager.hyprland.settings = {
    bind = [
      "L_ALT,TAB,exec,${pkgs.snappy-switcher}/bin/snappy-switcher next"
      "L_ALT&L_SHIFT,TAB,exec,${pkgs.snappy-switcher}/bin/snappy-switcher prev"
    ];

    layerrule = [
      "match:namespace snappy-switcher, order 1000"
    ];

    exec-once = [
      "app2unit --${pkgs.snappy-switcher}/bin/snappy-switcher --daemon"
    ];
  };
}
