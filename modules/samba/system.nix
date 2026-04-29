# samba server with recommended fruit config baked in.
# https://wiki.samba.org/index.php/Configure_Samba_to_Work_Better_with_Mac_OS_X
#
# hosts extend services.samba.settings with their own shares + workgroup
#
# windows discovery via samba-wsdd; macOS discovery via avahi (if avahi is enabled).
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
      # SMB3 needed to negotiate fruit/streams_xattr with modern macOS.
      "min protocol" = "SMB3";
      "vfs objects" = "catia fruit streams_xattr";
      # store apple metadata as alternate data streams; no AppleDouble files.
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

  # if the host also enables avahi, advertise SMB so macOS Finder discovers it.
  services.avahi.extraServiceFiles.smb = lib.mkIf config.services.avahi.enable (
    builtins.readFile ./avahi-smb.xml
  );
}
