# macos ships its own sshd (Remote Login); there is no services.openssh on
# nix-darwin. the stock /etc/ssh/sshd_config Includes sshd_config.d/* before
# its own settings and sshd honors the first value it sees, so a 000- drop-in
# imposes the fleet policy over both macos' 100-macos.conf and the defaults
{
  lib,
  shared,
  username,
  ...
}: let
  crypto = import ./_common.nix;
  # no DH-GEX on darwin: the nixos module pairs it with a hardened moduli
  # file, but macos' stock /etc/ssh/moduli still contains 2048-bit groups,
  # which would undercut the fleet's crypto floor
  kex = lib.filter (k: k != "diffie-hellman-group-exchange-sha256") crypto.kexAlgorithms;
in {
  environment.etc."ssh/sshd_config.d/000-nix-darwin.conf".text = ''
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    PermitRootLogin no
    AllowUsers ${username}

    KexAlgorithms ${lib.concatStringsSep "," kex}
    Ciphers ${lib.concatStringsSep "," crypto.ciphers}
    Macs ${lib.concatStringsSep "," crypto.macs}
    HostKeyAlgorithms ${crypto.hostKeyAlgorithms}
    PubkeyAcceptedAlgorithms ${crypto.pubkeyAcceptedAlgorithms}
    CASignatureAlgorithms ${crypto.caSignatureAlgorithms}
    RequiredRSASize ${toString crypto.requiredRSASize}

    # CVE-2002-20001 mitigation
    MaxStartups 10:30:100
    PerSourceMaxStartups 1
  '';

  # the same keyring contract as the nixos module: every .pub in the shared
  # keyring gets shell here. via home-manager since nix-darwin has no
  # users.users.*.openssh
  home-manager.users.${username}.home.file.".ssh/authorized_keys".text =
    lib.concatMapStrings (f: lib.fileContents (shared.keyring + "/${f}") + "\n")
    (lib.filter (lib.hasSuffix ".pub")
      (builtins.attrNames (builtins.readDir shared.keyring)));

  # keep Remote Login on; launchctl instead of systemsetup so activation
  # doesn't need Full Disk Access
  system.activationScripts.postActivation.text = ''
    launchctl enable system/com.openssh.sshd
    launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
  '';
}
