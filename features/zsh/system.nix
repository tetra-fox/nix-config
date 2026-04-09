{ pkgs, username, ... }:

{
  users.users.${username}.shell = pkgs.zsh;

  environment.pathsToLink = [ "/share/zsh" ];

  programs.zsh.enable = true;
}
