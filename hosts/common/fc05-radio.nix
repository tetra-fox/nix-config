# where the fc05 stream lives, read by mesa-svc-01 (which serves it) and mesa-pbx-01 (which plays it on hold)
{
  subdomain = "fc05";
  mount = "stream";
  # has no route through the edge, so only the pbx reaches it
  control = {
    port = 8011;
    previous = "/previous";
    next = "/next";
  };
}
