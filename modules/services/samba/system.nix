# fruit config follows https://wiki.samba.org/index.php/Configure_Samba_to_Work_Better_with_Mac_OS_X
{
  config,
  lib,
  ...
}: let
  cfg = config.lab.samba;
  passwordSecret = user: "samba/passwords/${user}";
in {
  options.lab.samba.accounts = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "linux users that can log in to samba, each with its password in the samba/passwords/<name> secret";
    example = ["tetra"];
  };

  options.lab.samba.localSid = lib.mkOption {
    type = lib.types.str;
    description = "the server's machine sid, which prefixes every account's sid. `net getlocalsid` prints it";
    example = "S-1-5-21-3417838047-1076818958-320801294";
  };

  config = {
    sops.secrets = lib.genAttrs (map passwordSecret cfg.accounts) (_: {
      restartUnits = ["samba-passdb.service" "samba-smbd.service"];
    });

    # the account database is rebuilt from the secrets on every start, so it holds exactly
    # the declared accounts and nothing under /var/lib/samba has to outlive a boot
    systemd.services.samba-passdb = {
      description = "build samba's account database from sops";
      requiredBy = ["samba-smbd.service"];
      before = ["samba-smbd.service"];
      path = [config.services.samba.package];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        rm -f /var/lib/samba/private/passdb.tdb
        net setlocalsid ${cfg.localSid}
        ${lib.concatMapStrings (user: ''
            password=$(cat ${config.sops.secrets.${passwordSecret user}.path})
            # -s reads the password and its confirmation from stdin
            printf '%s\n%s\n' "$password" "$password" | smbpasswd -s -a ${lib.escapeShellArg user}
          '')
          cfg.accounts}
      '';
    };

    services = {
      samba = {
        enable = true;
        openFirewall = true;

        settings.global = {
          workgroup = lib.mkDefault "WORKGROUP";
          "netbios name" = lib.mkDefault config.networking.hostName;
          "server string" = lib.mkDefault config.networking.hostName;
          # clients arrive on the server VLAN, never listen on the internal fabric
          interfaces = "lo ${config.lab.site.serverInterface}";
          "bind interfaces only" = "yes";
          security = "user";
          "guest account" = "nobody";
          "map to guest" = "Bad User";

          "server min protocol" = "SMB3_11";
          # otherwise time machine images cross the VLAN signed but unencrypted.
          # SMB 3.1.1 mandates encryption support, so this locks nobody out
          "server smb encrypt" = "required";
          "server role" = "standalone server";

          "vfs objects" = "catia fruit streams_xattr";
          "ea support" = "yes";
          "durable handles" = "yes";

          "load printers" = "no";
          "disable spoolss" = "yes";

          "fruit:aapl" = "yes";
          "fruit:posix_rename" = "yes";
          "fruit:metadata" = "stream";
          "fruit:resource" = "stream";
          "fruit:veto_appledouble" = "yes";
          "fruit:delete_empty_adfiles" = "yes";
          "fruit:wipe_intentionally_left_blank_rfork" = "yes";
        };
      };

      samba-wsdd = {
        enable = true;
        openFirewall = true;
        # discovery announces on the client-facing VLAN only, same scope as smbd
        interface = config.lab.site.serverInterface;
      };

      avahi.extraServiceFiles.smb = lib.mkIf config.services.avahi.enable (
        builtins.readFile ./avahi-smb.xml
      );
    };
  };
}
