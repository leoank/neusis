{ pkgs, ... }:
let
  # Use the stable symlink path, not Nix store paths. When a user runs
  # `sudo journalctl`, sudo resolves the command via PATH to
  # /run/current-system/sw/bin/journalctl. If the sudoers rule uses a
  # /nix/store/... path, it won't match — sudo does not follow symlinks
  # when comparing command paths against rules. The /run/current-system/sw/bin/
  # path is stable across rebuilds (the symlink target changes, the path
  # does not). We ensure all tools are in environment.systemPackages so
  # they appear at this path.
  sw = "/run/current-system/sw/bin";
in
{
  # Diagnostic tools needed by sudo rules below. Some of these aren't
  # installed by default or only available via module store paths (not
  # in the system profile). Adding them here ensures they resolve
  # consistently through /run/current-system/sw/bin/.
  environment.systemPackages = with pkgs; [
    smartmontools # smartctl
    nvme-cli # nvme
    pciutils # lspci
    dmidecode
    # journalctl, dmesg, lsblk, ip — already in system profile via systemd/util-linux/iproute2
    # zpool, zfs — already in system profile via ZFS module
    # mdadm — already in system profile via boot.swraid or md module
  ];

  security.sudo = {
    extraRules = [
      {
        groups = [ "wheel" ];
        commands = [
          # === Tier 1: Read-only diagnostics (NOPASSWD) ===
          # These commands are safe for unattended use (e.g., Claude Code
          # troubleshoot skill). Destructive operations (nixos-rebuild,
          # zfs set/destroy, systemctl restart, reboot) stay behind a password.

          # Log inspection
          { command = "${sw}/journalctl"; options = [ "NOPASSWD" ]; }
          { command = "${sw}/dmesg"; options = [ "NOPASSWD" ]; }

          # Storage health
          { command = "${sw}/smartctl"; options = [ "NOPASSWD" ]; }
          { command = "${sw}/nvme"; options = [ "NOPASSWD" ]; }
          { command = "${sw}/mdadm --detail *"; options = [ "NOPASSWD" ]; }
          { command = "${sw}/mdadm --examine *"; options = [ "NOPASSWD" ]; }

          # ZFS read-only
          { command = "${sw}/zpool status *"; options = [ "NOPASSWD" ]; }
          { command = "${sw}/zpool list *"; options = [ "NOPASSWD" ]; }
          { command = "${sw}/zpool get *"; options = [ "NOPASSWD" ]; }
          { command = "${sw}/zpool iostat *"; options = [ "NOPASSWD" ]; }
          { command = "${sw}/zfs list *"; options = [ "NOPASSWD" ]; }
          { command = "${sw}/zfs get *"; options = [ "NOPASSWD" ]; }

          # Hardware inspection
          { command = "${sw}/lsblk"; options = [ "NOPASSWD" ]; }
          { command = "${sw}/lspci"; options = [ "NOPASSWD" ]; }
          { command = "${sw}/dmidecode"; options = [ "NOPASSWD" ]; }

          # Network diagnostics
          { command = "${sw}/ip"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];

    # Global credential cache: authenticate once, all sessions (including
    # Claude Code subshells) inherit sudo for 15 minutes. Covers Tier 2
    # commands (nixos-rebuild, zfs set, systemctl restart) without needing
    # NOPASSWD — just run `sudo -v` at the start of a session.
    extraConfig = ''
      Defaults timestamp_type=global
      Defaults timestamp_timeout=15
    '';
  };
}
