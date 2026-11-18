{ pkgs, username, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  programs.fish.enable = true;
  programs.git.enable = true;

  home.packages = with pkgs; [
    nodejs
    javaPackages.compiler.temurin-bin.jdk-25
  ];
}
