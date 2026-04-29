#!/usr/bin/env bash
ip netns exec "$NETNS" ip link del wg0 2>/dev/null || true
