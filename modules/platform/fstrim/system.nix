_: {
  services.fstrim = {
    enable = true;
    # servers are UTC. monday 14:00 is 6a/7a pacific, after gc and optimise free blocks
    # see SCHEDULE.md
    interval = "Mon 14:00";
  };
}
