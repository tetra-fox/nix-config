{lib, ...}: let
  opAgent = "~/.1password/agent.sock";

  opSshVaults = [
    "Private"
    "mesa"
    "homelab_DTW"
  ];
in {
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
