#!/usr/bin/env bash

set -Eeuo pipefail

readonly network_test_host="cache.nixos.org"

usage() {
  echo "Usage: $0 [/dev/disk/by-id/<drive>]" >&2
}

if (($# > 1)); then
  usage
  exit 2
fi

if ((EUID != 0)); then
  script_path="$(readlink -f "$0")"
  echo "Switching to a root login environment with sudo -i..."
  exec sudo -i -- "$script_path" "$@"
fi

echo "Checking network access with $network_test_host..."
if ! ping -c 1 -W 5 "$network_test_host" >/dev/null 2>&1; then
  echo >&2
  echo "No network connection was detected." >&2
  echo "Run 'nmtui' to configure a network, then re-run this installer." >&2
  exit 1
fi
echo "Network connection detected."

if [[ ! -d /sys/firmware/efi/efivars ]]; then
  echo "The NixOS Minimal ISO must be booted in UEFI mode." >&2
  exit 1
fi

# check_disk <path> <label>: must be a whole, unmounted disk.
check_disk() {
  local disk="$1" label="$2" mounted
  if [[ ! -b "$disk" ]]; then
    echo "$label: not a block device: $disk" >&2
    exit 1
  fi
  if [[ "$(lsblk -dnro TYPE "$disk")" != "disk" ]]; then
    echo "$label: select an entire drive, not a partition: $disk" >&2
    exit 1
  fi
  mounted="$(lsblk -nrpo MOUNTPOINT "$disk" | sed '/^$/d')"
  if [[ -n "$mounted" ]]; then
    echo "$label: the drive or one of its partitions is mounted:" >&2
    echo "$mounted" >&2
    echo "Unmount it before re-running this installer." >&2
    exit 1
  fi
}

target_disk="${1:-}"
data_disk=""

echo
echo "Available drives:"
lsblk -d -e 7 -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN,TYPE
echo
echo "Tip: ls -l /dev/disk/by-id/ shows stable names for each drive."

if [[ -z "$target_disk" ]]; then
  echo
  read -r -p "Boot drive (SSD) to erase (prefer /dev/disk/by-id/...): " target_disk
fi
check_disk "$target_disk" "Boot drive"

echo
read -r -p "Also set up a storage drive (HDD) at /data? [y/N]: " want_storage
if [[ "$want_storage" =~ ^[Yy]$ ]]; then
  read -r -p "Storage drive (HDD) to erase: " data_disk
  check_disk "$data_disk" "Storage drive"

  if [[ "$(readlink -f "$data_disk")" == "$(readlink -f "$target_disk")" ]]; then
    echo "The boot drive and the storage drive must be different drives." >&2
    exit 1
  fi
fi

echo
echo "Disko will completely erase the boot drive and create:"
echo "  - 1 GiB EFI System Partition mounted at /boot"
echo "  - 4 GiB swap partition"
echo "  - ext4 root partition using the remaining space"
echo
lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN,TYPE,MOUNTPOINTS "$target_disk"

if [[ -n "$data_disk" ]]; then
  echo
  echo "Disko will also completely erase the storage drive and create:"
  echo "  - one ext4 partition (label 'data') mounted at /data"
  echo
  lsblk -o NAME,PATH,SIZE,MODEL,SERIAL,TRAN,TYPE,MOUNTPOINTS "$data_disk"
fi

echo
read -r -p "Type 'ERASE' to erase the drives listed above: " confirmation

if [[ "$confirmation" != "ERASE" ]]; then
  echo "Installation cancelled."
  exit 1
fi

username="${NIXSERVER_USER:-USERNAME}"
flake_ref="${NIXSERVER_FLAKE:-github:reqxdev/NixServer#NixServer}"
flake_source="${flake_ref%%#*}"
config_source="${NIXSERVER_SOURCE:-$flake_source}"
mount_point="/mnt"
config_target="$mount_point/etc/nixos"
swap_device="/dev/disk/by-label/swap"

if [[ ! -d "$config_source" ]]; then
  echo "Cannot locate the flake source to copy into /etc/nixos: $config_source" >&2
  echo "Run the installer through 'nix run', as documented in README.md." >&2
  exit 1
fi

storage_args=()
if [[ -n "$data_disk" ]]; then
  storage_args=(--argstr data "$data_disk")
fi

echo
echo "Wiping, partitioning, formatting, and mounting with Disko..."
disko \
  --mode destroy,format,mount \
  --flake "$flake_source#install" \
  --argstr device "$target_disk" \
  "${storage_args[@]}" \
  --root-mountpoint "$mount_point" \
  --yes-wipe-all-disks

if ! swapon --show=NAME --noheadings --raw | grep -Fxq "$(readlink -f "$swap_device")"; then
  swapon "$swap_device"
fi

if [[ -n "$data_disk" ]]; then
  # Give the main user (uid 1000, group users) ownership of the storage drive.
  chown 1000:100 "$mount_point/data"
fi

echo
echo "Copying the editable configuration to $config_target (/etc/nixos after reboot)..."
install -d -m 0755 "$config_target"
cp -a --no-preserve=ownership "$config_source/." "$config_target/"
chmod -R u+rwX "$config_target"

echo
echo "Generating hardware configuration for this machine..."
nixos-generate-config --root "$mount_point" --no-filesystems

echo
echo "Swap is active. Building and installing NixServer..."
nixos-install \
  --flake "path:$config_target#${flake_ref#*#}" \
  --root "$mount_point" \
  --no-channel-copy \
  --no-root-password \
  --max-jobs 1 \
  --cores 1

echo
echo "Set the root password for the installed system."
nixos-enter --root "$mount_point" --command "passwd root"

echo
echo "Set the password for user $username (used for sudo)."
nixos-enter --root "$mount_point" --command "passwd $username"

echo
echo "Installation complete. Reboot when ready."
echo "After reboot, run 'sudo tailscale up' on the console, then SSH in over Tailscale: ssh $username@nixserver"
echo "Edit your Nix configuration in /etc/nixos."
echo "Apply changes with: sudo nixos-rebuild switch --flake /etc/nixos#${flake_ref#*#}"
