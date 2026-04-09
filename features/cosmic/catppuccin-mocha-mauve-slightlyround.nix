# Converted from catppuccin/cosmic-desktop/themes/cosmic-settings/catppuccin-mocha-mauve+round.ron
{ cosmicLib, ... }:
let
  c = cosmicLib.cosmic;
  raw = c.mkRON "raw";
  rgba = r: g: b: a: {
    red = raw r;
    green = raw g;
    blue = raw b;
    alpha = raw a;
  };
  rgb = r: g: b: {
    red = raw r;
    green = raw g;
    blue = raw b;
  };
in
{
  wayland.desktopManager.cosmic.appearance.theme.dark = {
    palette = c.mkRON "enum" {
      variant = "Dark";
      value = [
        {
          name = "Catppuccin-Mocha-Mauve";
          blue = rgba "0.53725490" "0.70588235" "0.98039216" "1.0";
          red = rgba "0.95294118" "0.54509804" "0.65882353" "1.0";
          green = rgba "0.65098039" "0.89019608" "0.63137255" "1.0";
          yellow = rgba "0.97647059" "0.88627451" "0.68627451" "1.0";
          gray_1 = rgba "0.09411765" "0.09411765" "0.14509804" "1.0";
          gray_2 = rgba "0.11764706" "0.11764706" "0.18039216" "1.0";
          gray_3 = rgba "0.19215686" "0.19607843" "0.26666667" "1.0";
          neutral_0 = rgba "0.06666667" "0.06666667" "0.10588235" "1.0";
          neutral_1 = rgba "0.09411765" "0.09411765" "0.14509804" "1.0";
          neutral_2 = rgba "0.11764706" "0.11764706" "0.18039216" "1.0";
          neutral_3 = rgba "0.19215686" "0.19607843" "0.26666667" "1.0";
          neutral_4 = rgba "0.27058824" "0.27843137" "0.35294118" "1.0";
          neutral_5 = rgba "0.34509804" "0.35686275" "0.43921569" "1.0";
          neutral_6 = rgba "0.42352941" "0.43921569" "0.52549020" "1.0";
          neutral_7 = rgba "0.49803922" "0.51764706" "0.61176471" "1.0";
          neutral_8 = rgba "0.57647059" "0.60000000" "0.69803922" "1.0";
          neutral_9 = rgba "0.65098039" "0.67843137" "0.78431373" "1.0";
          neutral_10 = rgba "0.72941176" "0.76078431" "0.87058824" "1.0";
          bright_green = rgba "0.65098039" "0.89019608" "0.63137255" "1.0";
          bright_red = rgba "0.95294118" "0.54509804" "0.65882353" "1.0";
          bright_orange = rgba "0.98039216" "0.70196078" "0.52941176" "1.0";
          ext_warm_grey = rgba "0.57647059" "0.60000000" "0.69803922" "1.0";
          ext_orange = rgba "0.98039216" "0.70196078" "0.52941176" "1.0";
          ext_yellow = rgba "0.97647059" "0.88627451" "0.68627451" "1.0";
          ext_blue = rgba "0.53725490" "0.70588235" "0.98039216" "1.0";
          ext_purple = rgba "0.70588235" "0.74509804" "0.99607843" "1.0";
          ext_pink = rgba "0.96078431" "0.76078431" "0.90588235" "1.0";
          ext_indigo = rgba "0.79607843" "0.65098039" "0.96862745" "1.0";
          accent_blue = rgba "0.53725490" "0.70588235" "0.98039216" "1.0";
          accent_red = rgba "0.95294118" "0.54509804" "0.65882353" "1.0";
          accent_green = rgba "0.65098039" "0.89019608" "0.63137255" "1.0";
          accent_warm_grey = rgba "0.57647059" "0.60000000" "0.69803922" "1.0";
          accent_orange = rgba "0.98039216" "0.70196078" "0.52941176" "1.0";
          accent_yellow = rgba "0.97647059" "0.88627451" "0.68627451" "1.0";
          accent_purple = rgba "0.70588235" "0.74509804" "0.99607843" "1.0";
          accent_pink = rgba "0.96078431" "0.76078431" "0.90588235" "1.0";
          accent_indigo = rgba "0.79607843" "0.65098039" "0.96862745" "1.0";
        }
      ];
    };

    spacing = {
      space_none = 0;
      space_xxxs = 4;
      space_xxs = 8;
      space_xs = 12;
      space_s = 16;
      space_m = 24;
      space_l = 32;
      space_xl = 48;
      space_xxl = 64;
      space_xxxl = 128;
    };

    # `slightlyround`
    corner_radii = {
      radius_0 = c.mkRON "tuple" [
        0.0
        0.0
        0.0
        0.0
      ];
      radius_xs = c.mkRON "tuple" [
        2.0
        2.0
        2.0
        2.0
      ];
      radius_s = c.mkRON "tuple" [
        8.0
        8.0
        8.0
        8.0
      ];
      radius_m = c.mkRON "tuple" [
        8.0
        8.0
        8.0
        8.0
      ];
      radius_l = c.mkRON "tuple" [
        8.0
        8.0
        8.0
        8.0
      ];
      radius_xl = c.mkRON "tuple" [
        8.0
        8.0
        8.0
        8.0
      ];
    };

    bg_color = c.mkRON "optional" {
      red = raw "0.11764706";
      green = raw "0.11764706";
      blue = raw "0.18039216";
      alpha = raw "1.0";
    };

    text_tint = c.mkRON "optional" (rgb "0.80392157" "0.83921569" "0.95686275");

    accent = c.mkRON "optional" (rgb "0.79607843" "0.65098039" "0.96862745");

    success = c.mkRON "optional" (rgb "0.65098039" "0.89019608" "0.63137255");

    warning = c.mkRON "optional" (rgb "0.97647059" "0.88627451" "0.68627451");

    destructive = c.mkRON "optional" (rgb "0.95294118" "0.54509804" "0.65882353");

    window_hint = c.mkRON "optional" (rgb "0.79607843" "0.65098039" "0.96862745");

    neutral_tint = c.mkRON "optional" (rgb "0.49803922" "0.51764706" "0.61176471");

    primary_container_bg = c.mkRON "optional" {
      red = raw "0.19215686";
      green = raw "0.19607843";
      blue = raw "0.26666667";
      alpha = raw "1.0";
    };

    secondary_container_bg = c.mkRON "optional" {
      red = raw "0.27058824";
      green = raw "0.27843137";
      blue = raw "0.35294118";
      alpha = raw "1.0";
    };

    is_frosted = false;

    gaps = c.mkRON "tuple" [
      0
      8
    ];

    active_hint = 3;
  };
}
