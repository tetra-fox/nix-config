{
  lib,
  pkgs,
  shared,
  username,
  ...
}: let
  common = import ./_common.nix;
in {
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
      # drop DH moduli under requiredRSASize, the size column is bits minus one.
      # ModuliFile is types.path and won't coerce a derivation
      ModuliFile = "${pkgs.runCommand "ssh-moduli-hardened" {} ''
        awk '$5 >= ${toString (common.requiredRSASize - 1)}' ${pkgs.openssh}/etc/ssh/moduli > $out
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

      MaxStartups = common.maxStartups;
      PerSourceMaxStartups = common.perSourceMaxStartups;
    };
  };
}
