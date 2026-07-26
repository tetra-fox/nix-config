# where the time is going: cpu, io and process state. everything here reads
# /proc or /sys, so linux only. the mon box scrapes long-run metrics; this is
# for the interactive pass when a graph says something is slow but not what
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    iotop-c # maintained c rewrite, so the binary is iotop-c rather than iotop
    ltrace
    psmisc # pstree, killall, fuser
    sysstat # iostat, pidstat, sar
  ];
}
