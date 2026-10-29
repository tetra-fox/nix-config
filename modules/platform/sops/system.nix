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
    # sops-install-secrets queues its reloads and restarts before it points /run/secrets at the
    # new secrets, so a unit that runs at once reads the old ones. ordering the units after it
    # holds their jobs until it exits
    # TODO: drop once sops-nix queues them after atomicSymlink (pkgs/sops-install-secrets/main.go)
    systemd.services = lib.mkIf config.sops.useSystemdActivation (lib.genAttrs (map (lib.removeSuffix ".service") (lib.filter (lib.hasSuffix ".service") (lib.unique (lib.concatMap (secret: secret.reloadUnits ++ secret.restartUnits) (lib.attrValues config.sops.secrets))))) (_: {
      after = ["sops-install-secrets.service"];
    }));

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
