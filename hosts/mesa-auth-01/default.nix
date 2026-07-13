{modules, ...}: {
  imports = [
    modules.profiles.server.system

    modules.services.podman.system
    modules.services.authentik.system
    modules.platform.sops.system
  ];

  lab = {
    sops.secretsFile = ../../secrets/mesa-auth-01.yaml;

    site.hostIp = "192.168.10.120";
    site.internalIp = "10.10.0.120";

    authentik.enable = true;
  };

  system.stateVersion = "26.11";
}
