# shared by system.nix (declares and seeds the zones) and rpz.nix (fetches into them)
{
  rpzDir = "/var/lib/named/rpz";

  # named refuses an empty or missing zone file. seeds each rpz file and prefixes hosts-format fetches
  rpzStubText = ''
    $TTL 30
    @ IN SOA localhost. hostmaster.localhost. 1 3600 900 604800 30
      IN NS  localhost.
  '';
}
