{ pkgs, ... }:

# Remote access over Tailscale. Run `sudo tailscale up` once to log in.
# SSH is handled by Tailscale (tailscale set --ssh) using Tailscale accounts,
# so there are no SSH keys or passwords. Who may SSH in as which user is set
# in the "ssh" section of the tailnet's Access controls.
{
  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--ssh" ];
  };

  # Example account for a friend (no sudo). Uncomment, rename, then allow it in
  # Access controls with "users": [ "friend" ].
  # users.users.friend = {
  #   isNormalUser = true;
  #   shell = pkgs.fish;
  # };
}
