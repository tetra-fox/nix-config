{
  config,
  lib,
  pkgs,
  ...
}: let
  # 1Password SSH agent socket. cross-platform path because myputer (darwin)
  # would put it in a Group Container, hara (linux) puts it under $HOME.
  opAgent =
    if pkgs.stdenv.isDarwin
    then "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    else "${config.home.homeDirectory}/.1password/agent.sock";

  opSshVaults = [
    "Private"
    "mesa"
    "homelab_DTW"
  ];
in {
  # set SSH_AUTH_SOCK so tools that bypass ~/.ssh/config (ssh-add, nixos-anywhere
  # internals, scripts that just call `ssh`) talk to 1P instead of whatever
  # gnome-keyring / cosmic-session set up.
  home.sessionVariables.SSH_AUTH_SOCK = opAgent;

  programs.ssh = {
    enable = true;

    enableDefaultConfig = false;

    matchBlocks."*" = {
      forwardAgent = true;
      addKeysToAgent = "no";
      compression = false;
      serverAliveInterval = 0;
      serverAliveCountMax = 3;
      hashKnownHosts = false;
      userKnownHostsFile = "~/.ssh/known_hosts";
      controlMaster = "no";
      controlPath = "~/.ssh/master-%r@%n:%p";
      controlPersist = "no";
      identityAgent = opAgent;
    };
  };

  xdg.configFile."1Password/ssh/agent.toml".text =
    lib.concatMapStringsSep "\n" (vault: ''
      [[ssh-keys]]
      vault = "${vault}"
    '')
    opSshVaults;
}
