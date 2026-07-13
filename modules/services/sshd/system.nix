{
  lib,
  pkgs,
  shared,
  username,
  ...
}: {
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

    # remove small diffie-hellman moduli
    moduliFile = pkgs.runCommand "ssh-moduli-hardened" {} ''
      awk '$5 >= 3071' ${pkgs.openssh}/etc/ssh/moduli > $out
    '';

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [username];

      KexAlgorithms = [
        "sntrup761x25519-sha512@openssh.com"
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
        "diffie-hellman-group16-sha512"
        "diffie-hellman-group18-sha512"
        "diffie-hellman-group-exchange-sha256"
      ];
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes256-ctr"
        "aes192-ctr"
        "aes128-gcm@openssh.com"
        "aes128-ctr"
      ];
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "umac-128-etm@openssh.com"
      ];
      HostKeyAlgorithms = "sk-ssh-ed25519-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256";
      PubkeyAcceptedAlgorithms = "sk-ssh-ed25519-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256";
      CASignatureAlgorithms = "ssh-ed25519,rsa-sha2-512,rsa-sha2-256";
      RequiredRSASize = 3072;

      # CVE-2002-20001 mitigation
      MaxStartups = "10:30:100";
      PerSourceMaxStartups = 1;
    };
  };
}
