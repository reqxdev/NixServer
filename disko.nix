# Disk layout. disko formats these in the installer and generates the
# matching fileSystems / swapDevices for the installed system.
{
  disko.devices.disk = {
    # Boot SSD.
    main = {
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            type = "EF00";
            size = "1G";
            content = {
              type = "filesystem";
              format = "vfat";
              extraArgs = [ "-n" "boot" ];
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          swap = {
            size = "4G";
            content = {
              type = "swap";
              extraArgs = [ "--label" "swap" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              extraArgs = [ "-L" "nixos" ];
              mountpoint = "/";
            };
          };
        };
      };
    };

    # Optional storage HDD at /data. The installer only formats it if chosen;
    # nofail lets the system boot without it.
    data = {
      type = "disk";
      content = {
        type = "gpt";
        partitions.data = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            extraArgs = [ "-L" "data" ];
            mountpoint = "/data";
            mountOptions = [
              "noatime"
              "nofail"
              "x-systemd.device-timeout=30s"
            ];
          };
        };
      };
    };
  };
}
