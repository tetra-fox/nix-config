# secure boot. lanzaboote signs systemd-boot and one uki per generation with the keys in
# pkiBundle. `sbctl create-keys` writes them, or autoGenerateKeys on the first boot
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.boot.lanzaboote;
  sdBoot = config.boot.loader.systemd-boot;
  esp = config.boot.loader.efi.efiSysMountPoint;
  # esp-relative paths the last install wrote, so one dropped from the config gets removed
  manifest = "${esp}/loader/extra-files";

  extras =
    sdBoot.extraFiles
    // lib.mapAttrs' (name: text: lib.nameValuePair "loader/entries/${name}" (pkgs.writeText name text))
    sdBoot.extraEntries;

  installExtra = dest: src:
    if lib.hasSuffix ".efi" (lib.toLower dest)
    then "install_efi ${src} ${lib.escapeShellArg "${esp}/${dest}"}\n"
    else "install -Dp ${src} ${lib.escapeShellArg "${esp}/${dest}"}\n";

  installExtras = pkgs.writeShellScript "install-boot-extras" ''
    set -euo pipefail
    PATH=${lib.makeBinPath [pkgs.coreutils pkgs.sbsigntool]}

    install_efi() {
      ${lib.optionalString cfg.allowUnsigned ''
      # as lzbt does with allowUnsigned, before the keys exist
      if [ ! -e ${cfg.privateKeyFile} ]; then
        install -Dp "$1" "$2"
        return
      fi
    ''}
      mkdir -p "$(dirname "$2")"
      sbsign --key ${cfg.privateKeyFile} --cert ${cfg.publicKeyFile} --output "$2" "$1"
    }

    # entries the nixpkgs systemd-boot installer wrote before lanzaboote took over the esp.
    # lzbt removes their kernels but not the entries
    rm -f ${esp}/loader/entries/nixos-*.conf

    if [ -e ${manifest} ]; then
      while IFS= read -r path; do
        rm -f "${esp}/$path"
      done < ${manifest}
    fi
    ${lib.concatStrings (lib.mapAttrsToList installExtra extras)}
    printf '%s\n' ${lib.escapeShellArgs (lib.attrNames extras)} > ${manifest}
  '';

  installBootLoader = pkgs.writeShellScript "install-lanzaboote-with-extras" ''
    set -euo pipefail
    ${config.boot.loader.external.installHook} "$@"
    ${installExtras}
  '';
in {
  imports = [inputs.lanzaboote.nixosModules.lanzaboote];

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # lanzaboote installs the loader and the generations but not systemd-boot's extraFiles and
  # extraEntries (memtest, uefi shell, windows). the systemd-boot module stays enabled so it
  # still computes those, and this installer replaces its own: lanzaboote first, then the
  # extras, with efi binaries signed so the firmware loads them under secure boot
  system.build.installBootLoader = lib.mkForce installBootLoader;

  environment.systemPackages = [pkgs.sbctl];

  environment.persistence.main.directories = [cfg.pkiBundle];

  systemd.services = {
    # on a persistent host the keys have to land on the volume, not under its mountpoint
    generate-sb-keys = lib.mkIf cfg.autoGenerateKeys.enable {
      unitConfig.RequiresMountsFor = cfg.pkiBundle;
    };
    # it re-signs what lanzaboote installed once the keys exist, the extras need the same
    prepare-sb-auto-enroll = lib.mkIf cfg.autoEnrollKeys.enable {
      unitConfig.RequiresMountsFor = cfg.pkiBundle;
      serviceConfig.ExecStartPost = installExtras;
    };
  };
}
