{
  config,
  fleetSites,
  lib,
  pkgs,
  serverUsername,
  ...
}: let
  opAgent =
    if pkgs.stdenv.isDarwin
    then "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    else "${config.home.homeDirectory}/.1password/agent.sock";

  # `ssh mesa-db-01` works from any workstation. `!*.*` skips targets that
  # already carry a domain
  fleetBlocks = lib.listToAttrs (map (site: {
      name = "${site}-* !*.*";
      value = {
        hostname = "%h.${site}.tetra.cool";
        user = serverUsername;
      };
    })
    fleetSites);
in {
  options.my.ssh.opVaults = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = ["Private"];
    description = "1password vaults the ssh agent serves keys from (agent.toml)";
  };

  config = {
    # point tools that bypass ~/.ssh/config (ssh-add, nixos-anywhere) at 1P, not whatever agent the session spawned
    home.sessionVariables.SSH_AUTH_SOCK = opAgent;

    programs.ssh = {
      enable = true;

      enableDefaultConfig = false;

      settings =
        fleetBlocks
        // {
          "*" = {
            # one key opens every fleet host and every host has passwordless sudo, so a
            # forwarded agent would let root anywhere act as you everywhere. nothing needs it
            forwardAgent = false;
            addKeysToAgent = "no";
            compression = false;
            serverAliveInterval = 0;
            serverAliveCountMax = 3;
            hashKnownHosts = false;
            userKnownHostsFile = "~/.ssh/known_hosts";
            controlMaster = "no";
            controlPath = "~/.ssh/master-%r@%n:%p";
            controlPersist = "no";
            # the darwin path has spaces, unquoted ssh rejects the whole config
            identityAgent = ''"${opAgent}"'';
          };
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
