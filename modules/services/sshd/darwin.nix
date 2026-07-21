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
  common = import ./_common.nix;
  # no DH-GEX on darwin: the nixos module pairs it with a hardened moduli
  # file, but macos' stock /etc/ssh/moduli still contains 2048-bit groups,
  # which would undercut the fleet's crypto floor
  kex = lib.filter (k: k != "diffie-hellman-group-exchange-sha256") common.kexAlgorithms;
in {
  environment.etc."ssh/sshd_config.d/000-nix-darwin.conf".text = ''
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    PermitRootLogin no
    AllowUsers ${username}

    KexAlgorithms ${lib.concatStringsSep "," kex}
    Ciphers ${lib.concatStringsSep "," common.ciphers}
    Macs ${lib.concatStringsSep "," common.macs}
    HostKeyAlgorithms ${common.hostKeyAlgorithms}
    PubkeyAcceptedAlgorithms ${common.pubkeyAcceptedAlgorithms}
    CASignatureAlgorithms ${common.caSignatureAlgorithms}
    RequiredRSASize ${toString common.requiredRSASize}

    MaxStartups ${common.maxStartups}
    PerSourceMaxStartups ${toString common.perSourceMaxStartups}
  '';

  # the same keyring contract as the nixos module. nix-darwin writes these to
  # /etc/ssh/nix_authorized_keys.d/%u, which its own 101-authorized-keys.conf
  # drop-in reads back with AuthorizedKeysCommand. writing ~/.ssh/authorized_keys
  # through home-manager instead does not work: it lands as a symlink into
  # /nix/store, and the store is group-writable (drwxrwxr-t), so StrictModes
  # refuses it with "bad ownership or modes for directory /nix/store"
  users.users.${username}.openssh.authorizedKeys.keys =
    common.keyringKeys lib shared.keyring;

  # keep Remote Login on; launchctl instead of systemsetup so activation
  # doesn't need Full Disk Access
  system.activationScripts.postActivation.text = ''
    launchctl enable system/com.openssh.sshd
    launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
  '';
}
