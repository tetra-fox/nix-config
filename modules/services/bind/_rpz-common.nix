# rpz facts shared by system.nix (seeds + declares the policy zones) and rpz.nix (fetches
# into them); plain data, not a module. the two must agree on the dir and the stub schema.
{
  rpzDir = "/var/lib/named/rpz";

  # named refuses to load a zone whose file is empty or missing, so each RPZ file is seeded
  # with this SOA+NS stub, and hosts-format fetches are prefixed with the same one
  rpzStubText = ''
    $TTL 30
    @ IN SOA localhost. hostmaster.localhost. 1 3600 900 604800 30
      IN NS  localhost.
  '';
}
