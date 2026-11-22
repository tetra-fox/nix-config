# secure boot. lanzaboote signs systemd-boot and one uki per generation with the keys in
# pkiBundle, which `sbctl create-keys` writes once per host
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
    then ''
      mkdir -p "$(dirname ${lib.escapeShellArg "${esp}/${dest}"})"
      sbsign --key ${cfg.privateKeyFile} --cert ${cfg.publicKeyFile} \
        --output ${lib.escapeShellArg "${esp}/${dest}"} ${src}
    ''
    else ''
      install -Dp ${src} ${lib.escapeShellArg "${esp}/${dest}"}
    '';

  installBootLoader = pkgs.writeShellScript "install-lanzaboote-with-extras" ''
    set -euo pipefail
    PATH=${lib.makeBinPath [pkgs.coreutils pkgs.sbsigntool]}

    ${config.boot.loader.external.installHook} "$@"

    if [ -e ${manifest} ]; then
      while IFS= read -r path; do
        rm -f "${esp}/$path"
      done < ${manifest}
    fi
    ${lib.concatStrings (lib.mapAttrsToList installExtra extras)}
    printf '%s\n' ${lib.escapeShellArgs (lib.attrNames extras)} > ${manifest}
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
}
