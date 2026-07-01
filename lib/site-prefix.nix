# strip the trailing -<role>-NN suffix to get a host's site. mesa-svc-01 -> mesa, hara -> hara.
# matches any lowercase role token, so a new tier needs no edit here.
_: name: let
  m = builtins.match "(.+)-[a-z]+-[0-9]+" name;
in
  if m == null
  then name
  else builtins.head m
