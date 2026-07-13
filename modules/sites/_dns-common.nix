# RPZ blocklist policy shared by every site's resolver. imported by the per-site dns
# facts files (mesa-dns.nix, fairlane-dns.nix), which keep the genuinely per-site parts
# (zone data, dual-stack knobs).
_: {
  lab.bind.rpzLists = [
    {
      name = "oisd.rpz";
      url = "https://big.oisd.nl/rpz";
      format = "rpz";
    }
    {
      name = "vrchat.rpz";
      url = "https://raw.githubusercontent.com/louisa-uno/VRChatAnalyticsBlocklist/main/hosts.txt";
      format = "hosts";
    }
  ];
}
