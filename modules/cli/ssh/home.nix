{
  config,
  lib,
  pkgs,
  ...
}: let
  # 1P agent socket: darwin stores it in a Group Container, linux under $HOME
  opAgent =
    if pkgs.stdenv.isDarwin
    then "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    else "${config.home.homeDirectory}/.1password/agent.sock";
in {
  options.my.ssh.opVaults = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = ["Private"];
    description = "1password vaults the ssh agent serves keys from (agent.toml)";
  };

  config = {
    # point tools that bypass ~/.ssh/config (ssh-add, nixos-anywhere) at 1P, not gnome-keyring / cosmic-session
    home.sessionVariables.SSH_AUTH_SOCK = opAgent;

    programs.ssh = {
      enable = true;

      enableDefaultConfig = false;

      settings."*" = {
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
      config.my.ssh.opVaults;
  };
}
