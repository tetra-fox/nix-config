{
  lib,
  pkgs,
  shared,
  username,
  ...
}: {
  # canonical user key from shared/keyring. lists merge across modules, so
  # any host can append more keys via
  # users.users.${username}.openssh.authorizedKeys.keys = [...] - no mkForce needed.
  users.users.${username}.openssh.authorizedKeys.keys = [
    (lib.fileContents (shared.keyring + "/tetra.pub"))
  ];

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

      # ssh-audit hardening
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
      # max 10 pending connections, drop at 30%, hard cap 100
      MaxStartups = "10:30:100";
      PerSourceMaxStartups = 1;
    };
  };
}
