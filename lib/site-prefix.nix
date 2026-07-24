# strip the trailing -<role>-NN suffix to get a host's site. mesa-svc-01 -> mesa, hara -> hara.
# the site is the first dash-free token and the role may contain dashes and digits, so a new
# tier needs no edit here, multi-token roles included (mesa-db-alt-01 -> mesa)
_: name: let
  m = builtins.match "([a-z]+)-[a-z0-9-]+-[0-9]+" name;
in
  if m == null
  then name
  else builtins.head m
