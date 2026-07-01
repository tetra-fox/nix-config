# fruit config follows https://wiki.samba.org/index.php/Configure_Samba_to_Work_Better_with_Mac_OS_X
{
  config,
  lib,
  ...
}: {
  services.samba = {
    enable = true;
    openFirewall = true;

    settings.global = {
      workgroup = lib.mkDefault "WORKGROUP";
      "netbios name" = lib.mkDefault config.networking.hostName;
      security = "user";
      "guest account" = "nobody";
      "map to guest" = "Bad User";
      # modern macOS needs SMB3 to negotiate fruit/streams_xattr
      "min protocol" = "SMB3";
      "vfs objects" = "catia fruit streams_xattr";
      "fruit:metadata" = "stream";
      "fruit:posix_rename" = "yes";
      "fruit:veto_appledouble" = "no";
      "fruit:nfs_aces" = "no";
      "fruit:wipe_intentionally_left_blank_rfork" = "yes";
      "fruit:delete_empty_adfiles" = "yes";
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  services.avahi.extraServiceFiles.smb = lib.mkIf config.services.avahi.enable (
    builtins.readFile ./avahi-smb.xml
  );
}
