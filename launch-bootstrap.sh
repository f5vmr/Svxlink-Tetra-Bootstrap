#!/bin/sh

set -eu

BOOTSTRAP_REPOSITORY_URL='https:'\
'//github.com/f5vmr/Svxlink-Tetra-Bootstrap.git'
BOOTSTRAP_BRANCH='main'
BOOTSTRAP_TEMPORARY_DIRECTORY=''

cleanup_bootstrap_checkout()
{
    case "${BOOTSTRAP_TEMPORARY_DIRECTORY}" in
        /tmp/svxlink-bootstrap.*)
            rm -rf -- "${BOOTSTRAP_TEMPORARY_DIRECTORY}"
            ;;
    esac
}

trap cleanup_bootstrap_checkout EXIT HUP INT TERM

if [ "$(id -u)" -ne 0 ]; then
    echo "SvxLink Bootstrap must be started with root authority." >&2
    echo "Run this launcher using sudo." >&2
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "This launcher requires Debian or Raspberry Pi OS." >&2
    exit 1
fi

BOOTSTRAP_OS_RELEASE_FILE="${SVXLINK_BOOTSTRAP_OS_RELEASE_FILE:-/etc/os-release}"

if [ ! -r "${BOOTSTRAP_OS_RELEASE_FILE}" ]; then
    echo "Cannot read ${BOOTSTRAP_OS_RELEASE_FILE}." >&2
    echo "SvxLink TETRA requires Raspberry Pi Trixie arm64." >&2
    exit 1
fi

ID=''
VERSION_CODENAME=''
DEBIAN_CODENAME=''
PRETTY_NAME=''

# /etc/os-release is a root-controlled operating-system file.
# Loading it here allows unsupported releases to be rejected before
# APT is used or any prerequisite packages are installed.
. "${BOOTSTRAP_OS_RELEASE_FILE}"

BOOTSTRAP_OS_ID="${ID:-}"
BOOTSTRAP_CODENAME="${VERSION_CODENAME:-${DEBIAN_CODENAME:-}}"
BOOTSTRAP_PRETTY_NAME="${PRETTY_NAME:-${BOOTSTRAP_OS_ID}}"

case "${BOOTSTRAP_OS_ID}" in
    debian|raspbian)
        ;;
    *)
        echo "Unsupported operating system: ${BOOTSTRAP_PRETTY_NAME}" >&2
        echo "SvxLink TETRA requires Raspberry Pi OS or Debian Trixie." >&2
        exit 1
        ;;
esac

if [ "${BOOTSTRAP_CODENAME}" != "trixie" ]; then
    echo "Unsupported operating-system release: ${BOOTSTRAP_PRETTY_NAME}" >&2
    echo "SvxLink TETRA requires Trixie." >&2
    exit 1
fi

BOOTSTRAP_ARCHITECTURE="$(dpkg --print-architecture)"

if [ "${BOOTSTRAP_ARCHITECTURE}" != "arm64" ]; then
    echo "Unsupported architecture: ${BOOTSTRAP_ARCHITECTURE}" >&2
    echo "SvxLink TETRA requires a 64-bit arm64 installation." >&2
    exit 1
fi

BOOTSTRAP_DEVICE_MODEL="$(
    tr -d '\000' < /proc/device-tree/model 2>/dev/null || true
)"

case "${BOOTSTRAP_DEVICE_MODEL}" in
    *"Raspberry Pi"*)
        ;;
    *)
        echo "SvxLink TETRA requires Raspberry Pi hardware." >&2
        exit 1
        ;;
esac

echo "Preparing SvxLink Bootstrap prerequisites..."

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install \
    --yes \
    --no-install-recommends \
    ca-certificates \
    git \
    python3 \
    python3-flask

BOOTSTRAP_TEMPORARY_DIRECTORY="$(
    mktemp -d /tmp/svxlink-bootstrap.XXXXXX
)"

echo "Obtaining SvxLink Bootstrap..."

git clone \
    --depth 1 \
    --branch "${BOOTSTRAP_BRANCH}" \
    --single-branch \
    "${BOOTSTRAP_REPOSITORY_URL}" \
    "${BOOTSTRAP_TEMPORARY_DIRECTORY}/repository"

cd "${BOOTSTRAP_TEMPORARY_DIRECTORY}/repository"

python3 web_manager.py
