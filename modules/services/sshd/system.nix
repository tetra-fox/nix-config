{
  lib,
  pkgs,
  shared,
  username,
  ...
}: let
  crypto = import ./_common.nix;
in {
  # every .pub in the shared keyring gets shell on every host: the directory is the
  # contract, so changing who has access means changing the keyring, not this module
  users.users.${username}.openssh.authorizedKeys.keys =
    map (f: lib.fileContents (shared.keyring + "/${f}"))
    (lib.filter (lib.hasSuffix ".pub")
      (builtins.attrNames (builtins.readDir shared.keyring)));

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

      KexAlgorithms = crypto.kexAlgorithms;
      Ciphers = crypto.ciphers;
      Macs = crypto.macs;
      HostKeyAlgorithms = crypto.hostKeyAlgorithms;
      PubkeyAcceptedAlgorithms = crypto.pubkeyAcceptedAlgorithms;
      CASignatureAlgorithms = crypto.caSignatureAlgorithms;
      RequiredRSASize = crypto.requiredRSASize;

      # CVE-2002-20001 mitigation
      MaxStartups = "10:30:100";
      PerSourceMaxStartups = 1;
    };
  };
}
