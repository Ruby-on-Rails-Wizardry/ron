#!/usr/bin/env bash
# Shared helpers for host-side bin/* and Taskfile recipes (sample app).
# shellcheck disable=SC2034

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# This app (ubuntu-sample / alpine-sample / arch-sample)
SAMPLE="${SAMPLE:-$(basename "${ROOT}")}"
# Matching base image flavor (ubuntu-mise / …)
FLAVOR_BASE="${FLAVOR_BASE:-ubuntu-mise}"
# Log prefix / compose project name
FLAVOR="${FLAVOR:-${SAMPLE}}"
# Development uses the sibling flavor image, not this repo's production Dockerfile.
IMAGE="${IMAGE:-${FLAVOR_BASE}:dev}"
CACHE_VOLUME="${CACHE_VOLUME:-${FLAVOR_BASE}-cache}"
# Production image tag (compose.prod.yml)
PROD_IMAGE="${PROD_IMAGE:-${SAMPLE}:prod}"

load_dotenv_if_unset() {
  local file=$1
  local line key val
  [[ -f "${file}" ]] || return 0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    [[ "${line}" =~ ^[[:space:]]*$ ]] && continue
    [[ "${line}" == *=* ]] || continue
    key="${line%%=*}"
    val="${line#*=}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    if declare -p "${key}" &>/dev/null; then
      continue
    fi
    if [[ "${val}" =~ ^\"(.*)\"$ ]]; then
      val="${BASH_REMATCH[1]}"
    elif [[ "${val}" =~ ^\'(.*)\'$ ]]; then
      val="${BASH_REMATCH[1]}"
    fi
    export "${key}=${val}"
  done <"${file}"
}

load_dotenv_if_unset "${ROOT}/.mise.env"
load_dotenv_if_unset "${ROOT}/.mise.env.local"

if [[ -z "${USER:-}" ]]; then
  USER="$(id -un 2>/dev/null || printf 'dev')"
  export USER
fi
if [[ -z "${SHELL:-}" ]]; then
  SHELL="/bin/bash"
  export SHELL
fi
export DEV_UID="${DEV_UID:-$(id -u)}"
export DEV_GID="${DEV_GID:-$(id -g)}"
export IMAGE_USER="${IMAGE_USER:-${USER}}"
# Default project is this sample root (compose + docker run both mount it).
PROJECT="${PROJECT:-${ROOT}}"
CACHE_ROOT="${CACHE_ROOT:-/cache}"
: "${POSTGRESQL_VERSION:=}"

log() {
  printf '%s: %s\n' "${SAMPLE}" "$*" >&2
}

die() {
  log "error: $*"
  exit 1
}

require_docker() {
  command -v docker >/dev/null 2>&1 || die "docker not found on PATH"
  docker info >/dev/null 2>&1 || die "docker daemon not reachable"
}

image_exists() {
  docker image inspect "${IMAGE}" >/dev/null 2>&1
}

ensure_image() {
  require_docker
  if image_exists; then
    return 0
  fi
  local candidate=""
  for candidate in \
    "${UBUNTU_MISE_ROOT:-}" \
    "${ROOT}/../ubuntu-mise" \
    "${ROOT}/../../ubuntu-mise"; do
    [[ -n "${candidate}" && -x "${candidate}/bin/build" ]] || continue
    log "image ${IMAGE} missing — building via ${candidate}"
    (
      cd "${candidate}"
      export IMAGE POSTGRESQL_VERSION DEV_UID DEV_GID IMAGE_USER
      ./bin/build
    )
    return 0
  done
  die "image ${IMAGE} missing — build base: (cd path/to/ubuntu-mise && task build) or set UBUNTU_MISE_ROOT"
}

ensure_cache_volume() {
  require_docker
  if ! docker volume inspect "${CACHE_VOLUME}" >/dev/null 2>&1; then
    log "creating volume ${CACHE_VOLUME}"
    docker volume create "${CACHE_VOLUME}" >/dev/null
  fi
}

_docker_tty_flags() {
  local -a flags=(-i)
  if [[ "${DOCKER_FORCE_TTY:-0}" == "1" ]] || [[ -t 0 ]]; then
    flags+=(-t)
  fi
  printf '%s\n' "${flags[@]}"
}

host_kind() {
  local uname_s
  uname_s="$(uname -s 2>/dev/null || printf 'unknown')"
  case "${uname_s}" in
    Darwin) printf 'macos\n' ;;
    Linux)
      if [[ -r /proc/version ]] && grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
        printf 'wsl\n'
      else
        printf 'linux\n'
      fi
      ;;
    *) printf 'unknown\n' ;;
  esac
}

_host_timezone_from_localtime() {
  local target=""
  if command -v realpath >/dev/null 2>&1; then
    target="$(realpath /etc/localtime 2>/dev/null || true)"
  fi
  if [[ -z "${target}" ]]; then
    target="$(readlink -f /etc/localtime 2>/dev/null || readlink /etc/localtime 2>/dev/null || true)"
  fi
  if [[ "${target}" == *zoneinfo/* ]]; then
    printf '%s\n' "${target##*zoneinfo/}"
    return 0
  fi
  return 1
}

host_timezone() {
  local z
  if [[ -n "${TZ:-}" ]]; then
    printf '%s\n' "${TZ}"
    return 0
  fi
  if [[ -r /etc/timezone ]]; then
    z="$(tr -d '[:space:]' </etc/timezone 2>/dev/null || true)"
    if [[ -n "${z}" ]]; then
      printf '%s\n' "${z}"
      return 0
    fi
  fi
  if command -v timedatectl >/dev/null 2>&1; then
    z="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
    if [[ -n "${z}" ]]; then
      printf '%s\n' "${z}"
      return 0
    fi
  fi
  if z="$(_host_timezone_from_localtime)"; then
    printf '%s\n' "${z}"
    return 0
  fi
  printf 'UTC\n'
}

export TZ="${TZ:-$(host_timezone)}"

run_in_image() {
  ensure_image
  ensure_cache_volume

  local -a tty
  mapfile -t tty < <(_docker_tty_flags)
  local tz
  tz="$(host_timezone)"

  # shellcheck disable=SC2086
  docker run --rm \
    "${tty[@]}" \
    -v "${PROJECT}:/work:cached" \
    -w /work \
    -v "${CACHE_VOLUME}:/cache" \
    -e "USER=${IMAGE_USER}" \
    -e "HOME=/home/${IMAGE_USER}" \
    -e "CACHE_ROOT=${CACHE_ROOT}" \
    -e "TZ=${tz}" \
    -e "TERM=${TERM:-xterm-256color}" \
    ${DOCKER_RUN_OPTS:-} \
    "${IMAGE}" \
    "$@"
}

print_config() {
  cat <<EOF
SAMPLE=${SAMPLE}
FLAVOR_BASE=${FLAVOR_BASE}
IMAGE=${IMAGE}
PROD_IMAGE=${PROD_IMAGE}
CACHE_VOLUME=${CACHE_VOLUME}
USER=${USER}
IMAGE_USER=${IMAGE_USER}
DEV_UID=${DEV_UID}
DEV_GID=${DEV_GID}
SHELL=${SHELL}
PROJECT=${PROJECT}
POSTGRESQL_VERSION=${POSTGRESQL_VERSION:-}
TZ=${TZ:-$(host_timezone)}
HOST_KIND=$(host_kind)
ROOT=${ROOT}
EOF
}
