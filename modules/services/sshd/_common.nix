# crypto policy shared by the nixos module (system.nix) and the darwin
# sshd_config.d drop-in (darwin.nix); plain data, not a module
{
  kexAlgorithms = [
    "sntrup761x25519-sha512@openssh.com"
    "curve25519-sha256"
    "curve25519-sha256@libssh.org"
    "diffie-hellman-group16-sha512"
    "diffie-hellman-group18-sha512"
    "diffie-hellman-group-exchange-sha256"
  ];
  ciphers = [
    "chacha20-poly1305@openssh.com"
    "aes256-gcm@openssh.com"
    "aes256-ctr"
    "aes192-ctr"
    "aes128-gcm@openssh.com"
    "aes128-ctr"
  ];
  macs = [
    "hmac-sha2-512-etm@openssh.com"
    "hmac-sha2-256-etm@openssh.com"
    "umac-128-etm@openssh.com"
  ];
  hostKeyAlgorithms = "sk-ssh-ed25519-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256";
  pubkeyAcceptedAlgorithms = "sk-ssh-ed25519-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256";
  caSignatureAlgorithms = "ssh-ed25519,rsa-sha2-512,rsa-sha2-256";
  requiredRSASize = 3072;
}
