# trialing as the fleet terminal; nixpkgs' ghostty is linux-only so darwin
# gets the upstream release repackaged as ghostty-bin
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
    };
  };
}
