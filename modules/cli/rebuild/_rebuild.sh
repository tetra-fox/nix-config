#!/usr/bin/env bash
# `rebuild` system binary. usage:
#   rebuild                                  # local switch
#   rebuild boot                             # local boot (any nixos-rebuild action)
#   rebuild dry-run                          # build + diff without activating
#   rebuild --target-host mesa-svc-01        # deploy switch to that host
#   rebuild boot --target-host mesa-svc-01   # deploy boot to that host
#   rebuild --target-host admin@1.2.3.4      # explicit user@ip target
#   rebuild --help                           # this message
#
# unrecognized flags pass through to nixos-rebuild (e.g. --show-trace).
#
# with --target-host:
#   - a bare host gets `admin@` prepended
#   - the flake attr is the target's short name; for a bare ip it's read
#     from the target's `hostname` over ssh
#   - --flake-attr overrides it, needed while the target's hostname isn't set
#   - run without sudo so ssh can use your agent
#
# local rebuilds work as the user or via `sudo rebuild`.
#
# on darwin, local actions go to `sudo darwin-rebuild` (switch/build/check/
# activate only). remote deploys build on the target since a mac can't build
# linux derivations.
set -e

darwin=""
[ "$(uname -s)" = Darwin ] && darwin=1

usage() {
  # prints the header comment block above. two -e exprs because \| alternation
  # is a GNU extension and bsd sed matches nothing
  sed -n '2,/^[^#]/p' "$0" | sed -n -e 's/^# //p' -e 's/^#$//p'
}

if [ -n "$SUDO_USER" ]; then
  # sudo leaves $HOME as root's. getent is glibc-only, macos keeps users in
  # directory services
  if [ -n "$darwin" ]; then
    user_home=$(dscl . -read "/Users/$SUDO_USER" NFSHomeDirectory 2>/dev/null | sed 's/^NFSHomeDirectory: //')
  else
    user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  fi
  # a failed lookup still exits 0 through the pipe, so set -e won't catch it
  [ -d "$user_home" ] || { echo "rebuild: could not resolve a home directory for $SUDO_USER" >&2; exit 1; }
else
  user_home=$HOME
fi
flake="${NIX_CONFIG_FLAKE:-$user_home/Documents/git/nix-config}"
if [ ! -f "$flake/flake.nix" ]; then
  echo "rebuild: no flake.nix at $flake - clone the nix-config repo there, or set NIX_CONFIG_FLAKE" >&2
  exit 1
fi

# the first bare token matching one of these is the action. everything else
# passes through verbatim so nixos-rebuild handles flag arity
actions=" switch boot test build dry-build dry-run dry-activate build-vm build-vm-with-bootloader build-image list-generations repl edit check activate changelog "

action=""
target_host=""
flake_attr=""
passthrough=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)        usage; exit 0 ;;
    --target-host)
      [ $# -ge 2 ] || { echo "rebuild: --target-host needs a value" >&2; exit 1; }
      target_host="$2"
      # an empty value would otherwise fall through to a local rebuild
      [ -n "$target_host" ] || { echo "rebuild: --target-host given an empty value" >&2; exit 1; }
      shift 2 ;;
    --target-host=*)
      target_host="${1#--target-host=}"
      [ -n "$target_host" ] || { echo "rebuild: --target-host given an empty value" >&2; exit 1; }
      shift ;;
    --flake-attr)
      [ $# -ge 2 ] || { echo "rebuild: --flake-attr needs a value" >&2; exit 1; }
      flake_attr="$2"; shift 2 ;;
    --flake-attr=*)   flake_attr="${1#--flake-attr=}"; shift ;;
    -*)               passthrough+=("$1"); shift ;;
    *)
      if [ -z "$action" ] && [[ "$actions" == *" $1 "* ]]; then
        action="$1"
      else
        passthrough+=("$1")
      fi
      shift
      ;;
  esac
done

action="${action:-switch}"

if [ -n "$target_host" ]; then
  case "$target_host" in
    *@*) ;;
    *)   target_host="@deployUser@@$target_host" ;;
  esac

  # under sudo there's no agent, which fails late as permission denied on the target
  if [ -z "$SSH_AUTH_SOCK" ] || [ ! -S "$SSH_AUTH_SOCK" ]; then
    echo "rebuild: no usable ssh agent (SSH_AUTH_SOCK unset or not a socket); are you running as root?" >&2
    echo "rebuild: run remote deploys without sudo so ssh can use your agent" >&2
    exit 1
  fi

  if [ -z "$flake_attr" ]; then
    derived="${target_host#*@}"
    if [[ "$derived" =~ ^[0-9]+(\.[0-9]+){3}$ || "$derived" == *:* ]]; then
      # ip literal, ask the host its name
      remote_name=$(ssh -o ConnectTimeout=5 -o BatchMode=yes "$target_host" hostname) || {
        echo "rebuild: couldn't reach $target_host to derive flake-attr; if the host is up but unprovisioned, pass --flake-attr <name>" >&2
        exit 1
      }
      flake_attr="${remote_name%%.*}"
      if [ -z "$flake_attr" ]; then
        # an empty attr would make nixos-rebuild default to the local host
        echo "rebuild: $target_host returned no usable hostname; pass --flake-attr <name>" >&2
        exit 1
      fi
    else
      # flake attrs are lowercase, dns names are case-insensitive
      short="${derived%%.*}"
      flake_attr="${short,,}"
    fi
  fi

  # a mac can't build linux derivations, so the target builds its own closure
  build_host=localhost
  [ -n "$darwin" ] && build_host="$target_host"

  # --elevate only exists in unstable's nixos-rebuild-ng, the mac's 26.05 build
  # still spells it --sudo
  elevate=(--elevate sudo)
  [ -n "$darwin" ] && elevate=(--sudo)

  echo "rebuild: remote $action -> $target_host (attr $flake_attr, build on $build_host)" >&2
  exec nixos-rebuild "$action" \
    --flake "$flake#$flake_attr" \
    --target-host "$target_host" \
    --build-host "$build_host" \
    "${elevate[@]}" \
    "${passthrough[@]}"
else
  host=$(hostname)
  host="${host%%.*}"
  # flake attrs are lowercase; macos hostnames are commonly mixed-case
  host="${host,,}"
  echo "rebuild: local $action -> $host" >&2
  if [ -n "$darwin" ]; then
    # darwin-rebuild has no --elevate. build as the user first so ssh-gated
    # inputs are fetched with our agent, then root's eval hits the store
    case "$action" in
      build | check | changelog)
        exec darwin-rebuild "$action" --flake "$flake#$host" "${passthrough[@]}"
        ;;
      *)
        nix build --no-link "$flake#darwinConfigurations.$host.system"
        exec sudo darwin-rebuild "$action" --flake "$flake#$host" "${passthrough[@]}"
        ;;
    esac
  fi
  # only activation is elevated, so eval reaches nix-secrets with our agent
  exec nixos-rebuild "$action" --flake "$flake#$host" --elevate sudo "${passthrough[@]}"
fi
