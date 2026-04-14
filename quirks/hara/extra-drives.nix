{ ... }:

let
  baseOptions = [
    "noauto"
    "nofail"
    "noatime"
    "x-systemd.automount"
    "uid=1000"
    "gid=100"
    "umask=0022"
  ];
  roOptions = baseOptions ++ [
    "ro"
    "x-systemd.idle-timeout=60"
  ];
  rwOptions = baseOptions ++ [
    "rw"
    "windows_names"
    "x-systemd.idle-timeout=0"
  ];
in
{
  boot.supportedFilesystems = [ "ntfs" ];

  fileSystems = {
    "/mnt/data" = {
      device = "/dev/disk/by-uuid/601C0E101C0DE1C0";
      fsType = "ntfs3";
      options = roOptions;
    };

    "/mnt/games" = {
      device = "/dev/disk/by-uuid/01D83AE4F9AF9D60";
      fsType = "ntfs3";
      options = rwOptions;
    };

    "/mnt/music" = {
      device = "/dev/disk/by-uuid/DECAF453CAF42A03";
      fsType = "ntfs3";
      options = roOptions;
    };

    "/mnt/wd-black" = {
      device = "/dev/disk/by-uuid/10AAA832AAA8166E";
      fsType = "ntfs3";
      options = roOptions;
    };

    "/mnt/vault" = {
      device = "/dev/disk/by-uuid/D6A03453A0343BF5";
      fsType = "ntfs3";
      options = roOptions;
    };

    "/mnt/windows" = {
      device = "/dev/disk/by-uuid/E2AAEB4BAAEB1AB5";
      fsType = "ntfs3";
      options = roOptions;
    };
  };
}
