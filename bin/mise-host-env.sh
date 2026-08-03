#!/usr/bin/env bash
# Emit `export KEY=val` lines for mise `[env] _.source`.
# Fills gaps only — never clobbers a value already set in the shell.
# Same contract as sibling *-mise flavors (see flavor bin/mise-host-env.sh).

set -euo pipefail

if [[ -z "${USER:-}" ]]; then
  USER="$(id -un 2>/dev/null || printf 'dev')"
fi
export USER

if [[ -z "${SHELL:-}" ]]; then
  if command -v getent >/dev/null 2>&1; then
    SHELL="$(getent passwd "$(id -un)" 2>/dev/null | awk -F: '{print $7}')"
  fi
  SHELL="${SHELL:-/bin/bash}"
fi
export SHELL

if [[ -z "${DEV_UID:-}" ]]; then
  DEV_UID="$(id -u)"
fi
export DEV_UID

if [[ -z "${DEV_GID:-}" ]]; then
  DEV_GID="$(id -g)"
fi
export DEV_GID

if [[ -z "${IMAGE_USER:-}" ]]; then
  IMAGE_USER="${USER}"
fi
export IMAGE_USER

if [[ -z "${TZ:-}" ]]; then
  if [[ -r /etc/timezone ]]; then
    TZ="$(tr -d '[:space:]' </etc/timezone 2>/dev/null || true)"
  fi
  if [[ -z "${TZ:-}" ]] && command -v timedatectl >/dev/null 2>&1; then
    TZ="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  fi
  if [[ -z "${TZ:-}" ]] && [[ -e /etc/localtime ]]; then
    _lt=""
    if command -v realpath >/dev/null 2>&1; then
      _lt="$(realpath /etc/localtime 2>/dev/null || true)"
    fi
    if [[ -z "${_lt}" ]]; then
      _lt="$(readlink -f /etc/localtime 2>/dev/null || readlink /etc/localtime 2>/dev/null || true)"
    fi
    if [[ "${_lt}" == *zoneinfo/* ]]; then
      TZ="${_lt##*zoneinfo/}"
    fi
    unset _lt
  fi
  TZ="${TZ:-UTC}"
fi
export TZ
