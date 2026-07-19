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
      # match the fleet zsh setup: no login shell needed, hm owns the env
      shell-integration-features = "no-cursor,sudo";

      # ported from the iterm2 profiles this replaces. the palette in use was
      # ghostty's built-in Lovelace with two entries changed, so take the
      # theme and override those rather than restating all sixteen
      theme = "Lovelace";
      background = "#101013";
      palette = ["8=#414458"];

      font-family = "CaskaydiaCove Nerd Font Mono";
      font-size = 13;

      # iterm2 ran two profiles, a normal window at 0.90 opacity and the
      # dropdown at 0.70. ghostty has a single config that the quick terminal
      # inherits, so both windows take the dropdown's value.
      # blur is an intensity here, not iterm2's radius, and the two scales
      # aren't comparable; true means 20, which upstream documents as the
      # point past which rendering gets unreliable
      background-opacity = 0.7;
      background-blur = true;

      cursor-style-blink = true;

      # the quake window. ghostty ships no default binding for it, so the
      # keybind is the part that does the work; global: makes it fire when
      # ghostty is unfocused, which needs accessibility permission on macos.
      # the two quick-terminal values below already match ghostty's defaults
      # and are set anyway to pin the behavior iterm2 was configured for,
      # dropping from the top and following to the focused space
      keybind = ["global:cmd+grave_accent=toggle_quick_terminal"];
      quick-terminal-position = "top";
      quick-terminal-space-behavior = "move";

      # tabs drawn into the titlebar, the nearest thing to iterm2's 32pt bar
      macos-titlebar-style = "tabs";

      # the iterm2 default profile had scrollback set to unlimited. ghostty
      # bounds it by bytes rather than lines, so this is 100mb
      scrollback-limit = 100000000;
    };
  };
}
