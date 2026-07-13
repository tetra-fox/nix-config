# fruit config follows https://wiki.samba.org/index.php/Configure_Samba_to_Work_Better_with_Mac_OS_X
{
  config,
  lib,
  ...
}: {
  services = {
    samba = {
      enable = true;
      openFirewall = true;

      settings.global = {
        workgroup = lib.mkDefault "WORKGROUP";
        "netbios name" = lib.mkDefault config.networking.hostName;
        security = "user";
        "guest account" = "nobody";
        "map to guest" = "Bad User";

        "server min protocol" = "SMB3_11";

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
    };

    avahi.extraServiceFiles.smb = lib.mkIf config.services.avahi.enable (
      builtins.readFile ./avahi-smb.xml
    );
  };
}
