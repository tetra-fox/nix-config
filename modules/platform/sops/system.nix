{
  config,
  lib,
  ...
}: let
  cfg = config.lab.sops;
in {
  options.lab.sops.secretsFile = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = let
      f = ../../../secrets + "/${config.networking.hostName}.yaml";
    in
      if builtins.pathExists f
      then f
      else null;
  };

  config = {
    sops = {
      age = {
        sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
        keyFile = null;
        generateKey = false;
      };

      defaultSopsFile = cfg.secretsFile;
    };
  };
}
