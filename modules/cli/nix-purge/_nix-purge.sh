#!/usr/bin/env bash
# `nix-purge` system binary. `nh clean all` collects every profile on the machine, then
# this adds what it leaves behind: nix's caches, build logs and stale boot entries

case "${1:-}" in
  "") ;;
  -h | --help)
    echo "usage: nix-purge   # delete old generations, drop nix caches and build logs, prune boot entries, optimise the store"
    exit 0
    ;;
  *)
    echo "nix-purge: unknown argument $1" >&2
    exit 1
    ;;
esac

# -H because macos sudo keeps the caller's HOME, and nix run as root with a
# HOME it does not own warns and falls back to root's passwd home on every call
sudo=(sudo -H)
if [ "$(id -u)" -eq 0 ]; then
  sudo=()
fi

# nix's eval and tarball cache, which lives outside the store where no gc
# reaches it. cleared before the collection below so the flake registry it roots
# goes with it. under sudo the cache worth clearing is the invoking user's
if [ -n "${SUDO_USER:-}" ]; then
  cache=$(sudo -Hu "$SUDO_USER" sh -c 'echo "${XDG_CACHE_HOME:-$HOME/.cache}"')
else
  cache=${XDG_CACHE_HOME:-$HOME/.cache}
fi
rm -rf "$cache/nix"

# root accumulates its own copy of the same cache from sudo rebuilds. ~root
# rather than /root because darwin keeps root's home at /var/root
root_cache=~root/.cache
"${sudo[@]}" rm -rf "$root_cache/nix"

# build logs are never garbage collected and grow without bound. dropping the
# lot also loses `nix log` output for paths still in the store
"${sudo[@]}" rm -rf /nix/var/log/nix/drvs

# keeps only the current generation of each profile. --no-gcroots leaves result links and
# direnv shells alone. nh elevates itself, sudo's secure_path could drop it from PATH
nh clean all --optimise --no-gcroots

# nixos only: rewrite the boot entries so the menu stops offering generations
# that were just deleted. nix-darwin has no such binary
if [ -x /run/current-system/bin/switch-to-configuration ]; then
  echo "nix-purge: pruning bootloader entries" >&2
  "${sudo[@]}" /run/current-system/bin/switch-to-configuration boot
fi
