{
  pkgs,
  config,
  ...
}:
{
  home.packages = [ pkgs.tailscale ];
  # systemd.user.services.tailscale-autoconnect = {
  #   Unit = {
  #     Description = "Automatic connection to Tailscale";
  #   };
  #
  #   # make sure tailscale is running before trying to connect to tailscale
  #   Install = {
  #     After = ["network-pre.target" "tailscale.service"];
  #     Wants = ["network-pre.target" "tailscale.service"];
  #     WantedBy = ["multi-user.target"];
  #   };
  #
  #   # set this service as a oneshot job
  #   Service = {
  #     Type = "oneshot";
  #     ExecStart = "${pkgs.writeShellScript "activate_tailscale" ''
  #       # wait for tailscaled to settle
  #       sleep 2
  #
  #       # check if we are already authenticated to tailscale
  #       status="$(${pkgs.tailscale}/bin/tailscale status -json | ${pkgs.jq}/bin/jq -r .BackendState)"
  #       if [ $status = "Running" ]; then # if so, then do nothing
  #         exit 0
  #       fi
  #
  #       # otherwise authenticate with tailscale
  #       ${pkgs.tailscale}/bin/tailscale up -authkey "$(cat ${config.age.secrets.tsauthkey.path})"
  #     ''}";
  #   };
  #};
}
