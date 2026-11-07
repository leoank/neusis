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
# access tokens (`oama authorize microsoft ak2396@cam.ac.uk --device` once;
# without --device oama waits for a browser redirect that never comes;
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
      # 0.22.0+: 0.20 piped the token record to `security -i`, which cuts a line
      # at ~4 KB, so a Microsoft record failed to store (oama issue #93).
      # Patched: 0.22.0 saves every refreshed token with `-U -T`, which rewrites
      # the item's access list each time, so macOS asks for the keychain
      # password ("security wants to change access permissions"); the patch
      # sets the access list only when it creates the item.
      oama = pkgs.unstable.oama.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./oama-keychain-update.patch ];
      });
      pass = name: "${pkgs.coreutils}/bin/cat ${config.age.secrets.${name}.path}";
      realName = "Ankur Kumar";
      # aerc filter: -f colours without a terminal, -P leaves paging to aerc;
      # the file name (when the part has one) picks the language.
      bat = ''${lib.getExe pkgs.bat} -fP --style=plain --theme=ansi ''${AERC_FILENAME:+"--file-name=$AERC_FILENAME"}'';
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
                trash = "[Gmail]/Bin"; # a UK account's name for Trash
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
              # The server's sieve filter scripts show up as folders that
              # can't be opened.
              mbsync.patterns = [
                "*"
                "!.dovecot.sieve"
                "!sieve*"
              ];
            };

            cam = {
              address = "ak2396@cam.ac.uk";
              inherit realName;
              flavor = "outlook.office365.com";
              userName = "ak2396@cam.ac.uk";
              passwordCommand = "${lib.getExe oama} access ak2396@cam.ac.uk";
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
            extraConfig = {
              # accounts.conf holds only credential commands, never a password.
              general.unsafe-accounts-conf = true;
              ui = {
                styleset-name = "terminal";
                index-columns = "date<10,name<22,flags>4,subject<*";
                column-date = "{{.DateAutoFormat .Date.Local}}";
                timestamp-format = "2006-01-02";
                this-day-time-format = "15:04";
                this-week-time-format = "Mon 15:04";
                this-year-time-format = "Jan 02";
                sidebar-width = 26;
                dirlist-tree = true;
                threading-enabled = true;
                mouse-enabled = true;
                fuzzy-complete = true;
                border-char-vertical = "│";
                border-char-horizontal = "─";
                icon-encrypted = "󰌾";
                icon-signed = "󰏪";
              };
              viewer = {
                pager = "${pkgs.less}/bin/less -Rc";
                alternatives = "text/plain,text/html";
                header-layout = "From,To,Cc,Date,Subject";
              };
              # Home Manager's aerc.conf replaces aerc's own, which is where
              # these live; without them aerc shows no message body.
              # The filters are aerc's own (libexec/aerc/filters, on PATH
              # for filters); html renders through w3m with no network.
              filters = {
                "text/plain" = "colorize";
                "text/calendar" = "calendar";
                "message/delivery-status" = "colorize";
                "message/rfc822" = "colorize";
                "text/html" = "! html";
                ".headers" = "colorize";
                # Code and config attachments: bat picks the language from
                # the file name, in the terminal's 16 colours like the
                # styleset. The first matching filter wins and HM writes the
                # keys sorted, so the .filename rule comes before text/plain
                # (attachments often arrive as text/plain or octet-stream).
                ".filename,~(?i)\\.(c|h|cc|cpp|hpp|go|rs|py|rb|js|jsx|ts|tsx|java|kt|swift|nix|sh|bash|zsh|fish|lua|r|jl|sql|json|ya?ml|toml|ini|conf|xml|tex|csv|md)$" =
                  bat;
                "text/x-*" = bat;
                "application/json" = "${bat} -l json";
                "application/x-sh" = "${bat} -l sh";
              };
            };
            # Only the 16 terminal colours, so aerc follows the stylix scheme
            # the terminal already uses (stylix has no aerc target).
            stylesets.terminal = ''
              *.default=true
              *.normal=true
              border.fg=8
              title.fg=4
              title.bold=true
              header.fg=4
              header.bold=true
              *error.fg=1
              *error.bold=true
              warning.fg=3
              success.fg=2
              statusline_default.fg=7
              statusline_default.bg=0
              statusline_error.fg=1
              statusline_success.fg=2
              tab.fg=8
              tab.selected.fg=4
              tab.selected.bold=true
              dirlist*.selected.fg=0
              dirlist*.selected.bg=4
              dirlist_unread.fg=6
              dirlist_unread.bold=true
              dirlist_recent.fg=6
              msglist_default.fg=7
              msglist_read.fg=8
              msglist_unread.fg=15
              msglist_unread.bold=true
              msglist_flagged.fg=3
              msglist_deleted.fg=1
              msglist_deleted.dim=true
              msglist_marked.bg=5
              msglist_marked.fg=0
              msglist_result.fg=2
              msglist_answered.fg=8
              msglist_pill.reverse=true
              msglist_thread_folded.fg=6
              msglist_*.selected.fg=0
              msglist_*.selected.bg=4
              msglist_*.selected.bold=true
              selector_focused.fg=0
              selector_focused.bg=4
              selector_chooser.bold=true
              completion_pill.reverse=true
              completion_description.dim=true
              completion_default.fg=7
              completion_gutter.bg=8
              part_mimetype.fg=8
              part_*.selected.fg=0
              part_*.selected.bg=4

              [viewer]
              *.default=true
              *.normal=true
              url.underline=true
              url.fg=4
              header.bold=true
              header.fg=4
              signature.dim=true
              diff_meta.bold=true
              diff_chunk.fg=6
              diff_add.fg=2
              diff_del.fg=1
              quote_*.fg=8
              quote_1.fg=6
              quote_2.fg=5
            '';
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
          home.packages = [ oama ];

          neusis.services.mail-sync = {
            enable = true;
            # Not /tmp: mbsync's errors can quote the sign-in exchange.
            logDir = "${config.home.homeDirectory}/Library/Logs";
          };
        }

        # Every account: synced with mbsync, indexed by notmuch, read in aerc.
        # A folder made on either side is made on the other (aerc's archive
        # moves into a local Archive folder, which must reach the server, or
        # the message would exist only here); deletes and moves made in aerc
        # reach the server (expunge both); a folder removed on either side is
        # never removed on the other.
        {
          accounts.email.accounts =
            lib.genAttrs
              [
                "leoank"
                "gmail"
                "mrclmb"
                "cam"
              ]
              (name: {
                mbsync = {
                  enable = true;
                  create = "both";
                  expunge = "both";
                  # The XOAUTH2 plugin cam needs is visible to every account,
                  # and mbsync prefers it where the server offers it (Gmail):
                  # pin the password accounts to PLAIN so a password is never
                  # sent as a bearer token.
                  extraConfig.account = lib.mkIf (name != "cam") { AuthMechs = "PLAIN"; };
                };
                notmuch.enable = true;
                aerc.enable = true;
              });
        }
      ];
    };
}
