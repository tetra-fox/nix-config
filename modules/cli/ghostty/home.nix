# nixpkgs' ghostty is linux-only so darwin gets the upstream release
# repackaged as ghostty-bin
{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    package =
      if pkgs.stdenv.isDarwin
      then pkgs.ghostty-bin
      else pkgs.ghostty;

    enableZshIntegration = true;

    settings = {
      shell-integration-features = "no-cursor,sudo";

      theme = "Lovelace";
      background = "#101013";
      palette = ["8=#414458"];

      font-family = "CaskaydiaCove Nerd Font Mono";
      font-size = 13;

      background-opacity = 0.7;
      background-blur = true;

      cursor-style-blink = true;

      keybind = ["global:cmd+grave_accent=toggle_quick_terminal"];
      quick-terminal-position = "top";
      quick-terminal-space-behavior = "move";

      macos-titlebar-style = "tabs";

      scrollback-limit = 100000000;
    };
  };
}
