# sshd keeps the first value it sees and the stock config Includes sshd_config.d/* first,
# so a 000- drop-in overrides macos' 100-macos.conf and defaults
{
  lib,
  shared,
  username,
  ...
}: let
  common = import ./_common.nix;
  # no DH-GEX: macos' stock moduli still has 2048-bit groups
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

  # not via home-manager: ~/.ssh/authorized_keys would symlink into the group-writable
  # store, and StrictModes refuses it
  users.users.${username}.openssh.authorizedKeys.keys =
    common.keyringKeys lib shared.keyring;

  # keep Remote Login on; launchctl instead of systemsetup so activation
  # doesn't need Full Disk Access
  system.activationScripts.postActivation.text = ''
    launchctl enable system/com.openssh.sshd
    launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
  '';
}
