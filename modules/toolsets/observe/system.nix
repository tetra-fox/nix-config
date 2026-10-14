# linux only, everything here reads /proc or /sys
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    iotop-c # maintained rewrite, binary is iotop-c
    ltrace
    psmisc # pstree, killall, fuser
    sysstat # iostat, pidstat, sar
  ];
}
