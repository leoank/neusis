# ank's mail (ADR-0019): mbsync pulls four accounts into ~/Maildir every five
# minutes, notmuch indexes it, aerc reads it and sends over SMTP. Agents read
# and search mail through notmuch on the maildir, without the IMAP passwords.
#
# Passwords are agenix secrets at stable paths under ~/.config/mail (a quoted
# launchd argument does not expand darwin's default $(getconf …) path). Fill
# them with `agenix edit modules/secrets/ank/<name>.age`, then `agenix rekey`:
#   mailGmail   a Google app password for leoank98@gmail.com
#   mailMigadu  the Migadu mailbox password for ank@leoank.me
#   mailMrclmb  the MRC LMB password for kumar
# ak2396@cam.ac.uk is Microsoft 365, which refuses passwords for IMAP/SMTP:
# oama keeps its OAuth2 refresh token in the login keychain and hands out
# access tokens (`oama authorize microsoft ak2396@cam.ac.uk` once;
# EXP-20261106-2s4hg4).
{ self, ... }:
{
  flake.neusis.users.ank.hmBundles.mail =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      pass = name: "${pkgs.coreutils}/bin/cat ${config.age.secrets.${name}.path}";
      realName = "Ankur Kumar";
    in
    {
      imports = [ self.homeModules.mail-sync ];

      config = lib.mkMerge [
        {
          age.secrets = lib.genAttrs [ "mailGmail" "mailMigadu" "mailMrclmb" ] (name: {
            rekeyFile = ../../secrets/ank/${name}.age;
            path = "${config.home.homeDirectory}/.config/mail/${name}";
          });

          accounts.email.maildirBasePath = "${config.home.homeDirectory}/Maildir";
          accounts.email.accounts = {
            leoank = {
              primary = true;
              address = "ank@leoank.me";
              inherit realName;
              flavor = "migadu.com";
              userName = "ank@leoank.me";
              passwordCommand = pass "mailMigadu";
            };

            gmail = {
              address = "leoank98@gmail.com";
              inherit realName;
              flavor = "gmail.com";
              passwordCommand = pass "mailGmail";
              folders = {
                sent = "[Gmail]/Sent Mail";
                drafts = "[Gmail]/Drafts";
                trash = "[Gmail]/Trash";
              };
              # Gmail shows each label as a folder; All Mail, Important and
              # Starred would sync every message a second time.
              mbsync.patterns = [
                "*"
                "![Gmail]/All Mail"
                "![Gmail]/Important"
                "![Gmail]/Starred"
              ];
              # Gmail files what its SMTP sends in Sent Mail itself.
              aerc.extraAccounts.copy-to = "";
            };

            mrclmb = {
              address = "kumar@mrclmb.ac.uk";
              inherit realName;
              userName = "kumar";
              passwordCommand = pass "mailMrclmb";
              imap = {
                host = "mail.mrclmb.ac.uk";
                port = 993;
              };
              smtp = {
                host = "mail.mrclmb.ac.uk";
                port = 465;
              };
            };

            cam = {
              address = "ak2396@cam.ac.uk";
              inherit realName;
              flavor = "outlook.office365.com";
              userName = "ak2396@cam.ac.uk";
              passwordCommand = "${lib.getExe pkgs.oama} access ak2396@cam.ac.uk";
              folders.sent = "Sent Items";
              mbsync.extraConfig.account.AuthMechs = "XOAUTH2";
              aerc = {
                imapAuth = "xoauth2";
                smtpAuth = "xoauth2";
                # Exchange files what its SMTP sends in Sent Items itself.
                extraAccounts.copy-to = "";
              };
            };
          };

          programs.mbsync = {
            enable = true;
            # XOAUTH2 for the Microsoft 365 account comes from a SASL plugin.
            package = pkgs.isync.override { withCyrusSaslXoauth2 = true; };
          };
          programs.notmuch.enable = true;
          programs.aerc = {
            enable = true;
            # accounts.conf holds only credential commands, never a password.
            extraConfig.general.unsafe-accounts-conf = true;
          };

          xdg.configFile."oama/config.yaml".text = ''
            encryption:
              tag: KEYRING
            services:
              microsoft:
                # Thunderbird's public Microsoft client id: universities that
                # allow Thunderbird allow it. Device-code flow, no secret.
                client_id: 9e5f94bc-e8a4-4e73-b8be-63364c29d753
          '';
          home.packages = [ pkgs.oama ];

          neusis.services.mail-sync.enable = true;
        }

        # Every account: synced with mbsync, indexed by notmuch, read in aerc.
        # Folders the server gains appear locally; deletes and moves made in
        # aerc reach the server (expunge both), but a folder removed on either
        # side is never removed on the other.
        {
          accounts.email.accounts =
            lib.genAttrs
              [
                "leoank"
                "gmail"
                "mrclmb"
                "cam"
              ]
              (_: {
                mbsync = {
                  enable = true;
                  create = "maildir";
                  expunge = "both";
                };
                notmuch.enable = true;
                aerc.enable = true;
              });
        }
      ];
    };
}
