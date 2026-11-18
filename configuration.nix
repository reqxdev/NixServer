{ pkgs, username, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./tailscale.nix
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 10;
    efi.canTouchEfiVariables = true;
  };

  hardware.enableRedistributableFirmware = true;

  networking.hostName = "NixServer";
  networking.networkmanager.enable = true; # nmtui / nmcli for headless setup
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      25565 # Minecraft server
    ];
  };
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "uk";

  users.mutableUsers = true;
  users.users.${username} = {
    uid = 1000;
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };
  programs.fish.enable = true;
  # Auto Login
  services.getty.autologinUser = username;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit username; };
    users.${username} = import ./home.nix;
  };

  services.fstrim.enable = true;
  services.fwupd.enable = true;
  services.smartd.enable = true;

  documentation.nixos.enable = false;

  environment.defaultPackages = [ ];

  environment.systemPackages = with pkgs; [
    zip
    unzip
    git
    gh
    tmux
    btop
  ];

  system.stateVersion = "26.05";
}
