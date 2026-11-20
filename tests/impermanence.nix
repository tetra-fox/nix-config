# boots modules.platform.impermanence on a tmpfs root twice. the host's identity (machine-id,
# ssh host key, userborn's passwd) and a persisted directory must be the same on the second
# boot, a file outside the persisted paths must be gone, and a persisted directory missing
# from the volume must come back without an activation error
{
  modules,
  inputs,
}: {
  name = "impermanence";

  node.specialArgs = {
    inherit modules inputs;
    username = "admin";
    shared.keyring = ../shared/keyring;
  };

  nodes.machine = {lib, ...}: {
    imports = [
      modules.platform.impermanence.system
      modules.services.sshd.system
    ];

    environment.persistence.main = {
      enable = true;
      directories = ["/var/lib/kept" "/var/lib/recreated"];
    };

    services.userborn.enable = true;
    users = {
      users.admin.isNormalUser = true;
      # no uid, so userborn allocates one and has to remember it
      users.dyn = {
        isSystemUser = true;
        group = "dyn";
      };
      groups.dyn = {};
    };

    # the disk the test driver would mount at / is the persistent volume instead
    virtualisation.fileSystems = {
      "/" = {
        device = lib.mkForce "none";
        fsType = lib.mkForce "tmpfs";
        options = ["mode=755"];
        neededForBoot = true;
      };
      "/persist" = {
        device = "/dev/vda";
        fsType = "ext4";
        neededForBoot = true;
      };
    };
  };

  testScript = ''
    identity = "cat /etc/machine-id /persist/etc/ssh/ssh_host_ed25519_key.pub && id dyn"

    machine.wait_for_unit("multi-user.target")
    # sshd is socket activated, nothing has connected to make it generate the keys
    machine.succeed("systemctl start sshd-keygen.service")
    machine.succeed("test $(readlink -f /etc/passwd) = /persist/etc/passwd")
    before = machine.succeed(identity)
    machine.succeed("touch /var/lib/kept/file /root/file")
    machine.succeed("rmdir /persist/var/lib/recreated")

    machine.shutdown()
    machine.start()

    machine.wait_for_unit("multi-user.target")
    after = machine.succeed(identity)
    assert before == after, f"identity changed across the reboot:\n{before}\n{after}"
    machine.succeed("test -e /var/lib/kept/file")
    machine.fail("test -e /root/file")
    machine.succeed("test -d /persist/var/lib/recreated")
    machine.fail("journalctl -b | grep 'Activation script snippet .* failed'")
  '';
}
