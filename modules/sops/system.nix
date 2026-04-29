{
  config,
  lib,
  ...
}: let
  cfg = config.lab.sops;
in {
  options.lab.sops.secretsFile = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = null;
  };

  config = {
    _module.args.siteEnvFile = name: [config.sops.templates.${name}.path];

    sops = {
      age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      age.keyFile = null;
      age.generateKey = false;

      defaultSopsFile = cfg.secretsFile;
    };
  };
}
