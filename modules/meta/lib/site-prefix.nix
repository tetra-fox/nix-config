# strip the trailing -<role>-NN suffix to get a host's site. mesa-svc-01 -> mesa, hara -> hara.
# the role list MUST cover every fleet tier or a host lands in a site of its own and the
# derives miss it.
{lib}: name: let
  m = builtins.match "(.+)-(svc|mon|store|db|auth|jelly|edge|dns)-[0-9]+" name;
in
  if m == null
  then name
  else builtins.head m
