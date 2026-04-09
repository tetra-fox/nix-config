{
  config,
  lib,
  pkgs,
  ...
}:

let
  style = builtins.readFile ./style.css;
  dev = true;
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = false;

    style = style;

    settings = [
      {
        height = 38;
        layer = "top";
        position = "top";

        reload_style_on_change = dev;

        modules-left = [ "hyprland/window" ];

        "hyprland/window" = {
          "separate-outputs" = true;
          "format" = "{initialTitle}";
          tooltip = false;
        };

        modules-right = [
          "tray"
          "wireplumber"
          "bluetooth"
          "network"
          "clock"
        ];

        clock = {
          interval = 1;
          format = "{:%a %d %b %H:%M:%S}";
        };

        tray = {
          icon_size = 24;
          spacing = 10;
        };

        wireplumber = {
          format = "{icon}";
          format-icons = [
            "󰕿"
            "󰖀"
            "󰕾"
          ];
          format-muted = "󰝟";
          # on-click = "helvum";
          scroll-step = 5;
          tooltip-format = "{volume}% ({node_name})";
        };

        network = {
          interval = 1;
          format-ethernet = "󰈀 {ipaddr}/{cidr}";
          format-linked = "󰈀 (no ip)";
          format-disconnected = "󰀦 Disconnected";
          format-wifi = "{icon} {essid} ({signaldBm} dBm)";
          format-icons = [
            "󰤟"
            "󰤢"
            "󰤥"
            "󰤨"
          ];
          format-alt = "󰇚 {bandwidthDownBits} 󰕒 {bandwidthUpBits}";
          tooltip-format = "{ifname}";
        };

        bluetooth = {
          format = "󰂯";
          tooltip-format = "{controller_alias} ({controller_address})";
          on-click = "overskride";
        };
      }
    ];
  };
}
