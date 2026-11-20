# / is wiped on every boot, only the paths in environment.persistence.main come back from the
# persistent volume. a module lists its own state next to the service that writes it. the
# volume and the ephemeral root come from the disk layout (modules.platform.disko.proxmox-vm)
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.environment.persistence.main;
  etc = "${cfg.persistentStoragePath}/etc";
in {
  imports = [inputs.impermanence.nixosModules.impermanence];

  config = lib.mkMerge [
    {
      environment.persistence.main = {
        enable = lib.mkDefault false;
        persistentStoragePath = "/persist";
        hideMounts = true;
        # its one warning wants /var/lib/nixos persisted for stable ids. userborn's files
        # are on the volume instead, see passwordFilesLocation below
        enableWarnings = false;

        directories = [
          "/var/log"
          # timer stamps, random seed, the timesync clock
          "/var/lib/systemd"
          "/var/lib/userborn"
          # every DynamicUser unit's state
          {
            directory = "/var/lib/private";
            mode = "0700";
          }
          # so large temporary files land on disk and not in the root tmpfs
          {
            directory = "/var/tmp";
            mode = "1777";
          }
        ];
        files = ["/etc/machine-id"];
      };
    }

    (lib.mkIf cfg.enable {
      # used in place on the volume instead of bound into /etc: userborn replaces passwd by
      # rename, which a bind mount blocks, and the host key is there for sops as soon as
      # the volume mounts
      services.userborn.passwordFilesLocation = etc;
      lab.sshd.hostKeyDir = "${etc}/ssh";

      # impermanence chowns a directory it has to create by user name, in an activation
      # script that runs before /etc/passwd points at the volume. ordered after `etc` the
      # name resolves on every boot except the first one of a fresh install
      # TODO: drop once impermanence supports userborn, https://github.com/nix-community/impermanence/pull/334
      system.activationScripts.createPersistentStorageDirs.deps = ["etc"];

      # activating on a root that is still the disk would bind new empty directories over
      # the running services' state. such a host takes this config with `boot` and a reboot
      system.preSwitchChecks.persistentVolume = ''
        case "$2" in
          switch | test)
            if ! ${pkgs.util-linux}/bin/mountpoint -q ${cfg.persistentStoragePath}; then
              echo "${cfg.persistentStoragePath} is not mounted, apply this configuration with boot and reboot into it"
              exit 1
            fi
            ;;
        esac
      '';
    })
  ];
}
