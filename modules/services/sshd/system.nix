{
  lib,
  pkgs,
  shared,
  username,
  ...
}: let
  common = import ./_common.nix;
in {
  # the directory is the contract, so changing who has access means changing
  # the keyring, not this module
  users.users.${username}.openssh.authorizedKeys.keys =
    common.keyringKeys lib shared.keyring;

  services.openssh = {
    enable = true;
    startWhenNeeded = true;

    hostKeys = [
      {
        type = "ed25519";
        path = "/etc/ssh/ssh_host_ed25519_key";
      }
      {
        type = "rsa";
        bits = 4096;
        path = "/etc/ssh/ssh_host_rsa_key";
      }
    ];

    settings = {
      # remove small diffie-hellman moduli. ModuliFile is types.path, not
      # types.package, so it won't coerce a derivation; interpolate to a string path
      ModuliFile = "${pkgs.runCommand "ssh-moduli-hardened" {} ''
        awk '$5 >= 3071' ${pkgs.openssh}/etc/ssh/moduli > $out
      ''}";

      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [username];

      KexAlgorithms = common.kexAlgorithms;
      Ciphers = common.ciphers;
      Macs = common.macs;
      HostKeyAlgorithms = common.hostKeyAlgorithms;
      PubkeyAcceptedAlgorithms = common.pubkeyAcceptedAlgorithms;
      CASignatureAlgorithms = common.caSignatureAlgorithms;
      RequiredRSASize = common.requiredRSASize;

      # CVE-2002-20001 mitigation
      MaxStartups = "10:30:100";
      PerSourceMaxStartups = 1;
    };
  };
}
