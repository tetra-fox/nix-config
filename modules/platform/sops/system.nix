{
  config,
  lib,
  ...
}: let
  cfg = config.lab.sops;
in {
  options.lab.sops.secretsFile = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    # every host's sops file is secrets/<hostname>.yaml by convention, so no host states
    # the path; a host without secrets (dns, fairlane-store) has no file and gets null
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
