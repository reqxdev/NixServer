{ config, ... }:

{
  imports = [
	./fish.nix
  ];

  home.stateVersion = "26.05";

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    download = "${config.home.homeDirectory}/Downloads";
    projects = "${config.home.homeDirectory}/Projects";

    desktop = null;
    documents = null;
    music = null;
    pictures = null;
    publicShare = null;
    templates = null;
    videos = null;
  };
}
