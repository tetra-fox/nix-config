# the single source of truth for "which site does this host belong to": strip the trailing
# -<role>-NN suffix from a hostname. mesa-svc-01 -> mesa, mesa-store-01 -> mesa,
# fairlane-svc-01 -> fairlane, hara -> hara (self-prefix). the role list MUST cover every
# fleet tier or a host lands in a site of its own and the derives miss it.
#
# imported by both site-topology.nix (the topology fold) and flake.nix (the colmena deploy
# tag) so the regex lives in exactly one place -- it drifted once when it was copy-pasted.
{lib}: name: let
  m = builtins.match "(.+)-(svc|mon|store|db|auth|jelly|edge)-[0-9]+" name;
in
  if m == null
  then name
  else builtins.head m
