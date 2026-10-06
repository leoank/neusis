#!/usr/bin/env nu
# Script: check-quotas.nu
# Purpose: Monitor /home/ usage and notify users exceeding quotas
# Requirements: Nix environment (run with: nix develop)
# See: ../CLAUDE.md for Nushell patterns and common pitfalls
#
# WHAT THIS SCRIPT DOES:
# ----------------------
# 1. Scans all user home directories (or specific user with --user flag)
# 2. Calculates total disk usage for each home directory
# 3. Identifies files larger than threshold (default: 1GB)
# 4. Sends Slack notifications to group channel when users need attention
# 5. Outputs summary table showing all users' status
#
# WHEN SLACK NOTIFICATIONS ARE SENT:
# -----------------------------------
# The script sends notifications to the Slack channel when:
# • User exceeds soft quota (default: 100GB) → "quota warning" notification
# • User has large files (>1GB) even if under quota → "reminder" notification
# • No notification sent if user is under quota with no large files
#
# Note: All notifications go to the configured Slack channel (ip-alert-servers)
#
# CONFIGURATION:
# -------------
# Settings are loaded in this order (first found wins):
#
# 1. Environment variables (highest priority):
#    HOME_BASE_DIR=/custom/path  # Where user homes are (default: /home or /Users on macOS)
#    QUOTA_GB=150                # Soft quota in GB (default: 100)
#    LARGE_FILE_GB=2             # Large file threshold in GB (default: 1)
#    SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...  # Webhook for Slack notifications
#    LOG_DIR=/var/log/custom     # Where to write logs (default: /var/log/lab-scripts)
#
# 2. Config file at ../config/quotas.yaml (relative to this script):
#    soft_quota_gb: 100
#    large_file_threshold_gb: 1
#    # Slack webhook is configured via SLACK_WEBHOOK_URL environment variable only
#    home_base: "/home"           # optional
#    log_dir: "/var/log/lab-scripts"  # optional
#
# 3. Built-in defaults (as shown above)
#
# SECURITY NOTE: Never store webhook URLs in config files. Use environment variables only.
#
# COMMON USAGE:
# ------------
# Production (sends Slack notifications):
#   nu check-quotas.nu                    # Check all users, send notifications
#   nu check-quotas.nu --user alice       # Check only alice, send notification if needed
#
# Testing (no notifications sent):
#   nu check-quotas.nu --dry-run          # Check all users, show what would happen
#   nu check-quotas.nu --test             # Same as --dry-run --verbose (detailed output)
#   nu check-quotas.nu --test --user bob  # Test specific user with details
#
# With sudo (for checking other users' directories):
#   sudo $(which nix) develop --command nu monitoring/check-quotas.nu
#   sudo $(which nix) develop --command nu monitoring/check-quotas.nu --user ank
#
# QUICK TEST SETUP:
# ----------------
# Create test data:
#   mkdir -p /tmp/test-home/{alice,bob,charlie}
#   dd if=/dev/zero of=/tmp/test-home/alice/bigfile.bin bs=1G count=2 2>/dev/null
#   dd if=/dev/zero of=/tmp/test-home/bob/data.tar bs=500M count=1 2>/dev/null
#
# Run test (alice over 1GB quota, bob under):
#   HOME_BASE_DIR=/tmp/test-home QUOTA_GB=1 nu check-quotas.nu --test
#
# Clean up:
#   rm -rf /tmp/test-home
#
# CRON AUTOMATION:
# ---------------
# For automated weekly checks, add to /etc/crontab:
#
# # Environment variables (update paths as needed)
# REPO_PATH=/path/to/imaging-server-maintenance
# SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
#
# # Weekly quota check - Monday 9 AM (runs as root for access to all user directories)
# 0 9 * * 1 root git config --global --add safe.directory ${REPO_PATH} && cd ${REPO_PATH} && /nix/var/nix/profiles/default/bin/nix develop --impure --command nu scripts/monitoring/check-quotas.nu
#
# Notes on cron setup:
# - The git config command prevents "dubious ownership" errors when root runs scripts in user-owned repos
# - Use --impure flag with nix develop to allow environment variables to pass through
# - Script logs to /var/log/lab-scripts/check-quotas.log and sends alerts to Slack
# - Adjust the schedule (0 9 * * 1) as needed: this runs every Monday at 9 AM

# Load configuration with simple precedence: env vars > config file > defaults
def config [] {
    let script_dir = ($env.FILE_PWD? | default $env.PWD)
    let config_file = $"($script_dir)/../config/quotas.yaml"

    # Load YAML config or use empty dict
    let yaml = if ($config_file | path exists) {
        open $config_file
    } else {
        {}
    }

    # Simple precedence: env vars override YAML, YAML overrides defaults
    {
        home_base: ($env.HOME_BASE_DIR? | default ($yaml.home_base? | default (if ($nu.os-info.name == "macos") { "/Users" } else { "/home" })))
        soft_quota_gb: ($env.QUOTA_GB? | default ($yaml.soft_quota_gb? | default 100) | into int)
        large_file_threshold_gb: ($env.LARGE_FILE_GB? | default ($yaml.large_file_threshold_gb? | default 1) | into int)
        slack_webhook_url: ($env.SLACK_WEBHOOK_URL? | default "")  # Only from env var for security
        log_dir: ($env.LOG_DIR? | default ($yaml.log_dir? | default (if ($nu.os-info.name == "macos") { "/tmp/lab-scripts" } else { "/var/log/lab-scripts" })))
    }
}

# Logging to stdout with timestamp and optional file
def log [level: string, message: string] {
    let timestamp = (date now | format date "%Y-%m-%d %H:%M:%S")
    let line = $"[($timestamp)] [($level)] ($message)"
    print $line

    # Best-effort file logging
    let cfg = (config)
    let log_file = $"($cfg.log_dir)/check-quotas.log"
    try {
        mkdir $cfg.log_dir | ignore
        $"($line)\n" | save --append $log_file
    } catch {
        # Silently fail if can't write to log
    }
}

# Get home directory usage for a user (excludes cache directories)
def get-user-usage [username: string] {
    let cfg = (config)
    let home_path = $"($cfg.home_base)/($username)"

    if not ($home_path | path exists) {
        return null
    }

    # Use GNU du with --exclude to skip cache directories
    # Excludes: .pixi/cache, .cache, .conda/pkgs (all package manager caches)
    let du_result = (^du -sb
        --exclude=".pixi/cache"
        --exclude=".cache"
        --exclude=".conda/pkgs"
        $home_path
        | complete)

    if $du_result.exit_code != 0 {
        log "WARNING" $"Failed to calculate usage for ($username): ($du_result.stderr)"
        return null
    }

    let size_bytes = ($du_result.stdout | lines | first | split row "\t" | first | into int)
    let gb_divisor = 1000000000  # 1GB in bytes

    {
        user: $username
        path: $home_path
        size_bytes: $size_bytes
        size_gb: ($size_bytes / $gb_divisor | math round -p 2)
    }
}

# Find large files using fd (required tool from flake.nix)
def get-large-files [username: string, threshold_gb: int] {
    let cfg = (config)
    let home_path = $"($cfg.home_base)/($username)"

    if not ($home_path | path exists) {
        return []
    }

    let threshold_bytes = $threshold_gb * 1GB

    # Use fd for fast file discovery (includes hidden directories with -H)
    # Exclude cache directories to match quota calculation
    # The complete command captures stdout/stderr separately for cleaner handling
    let fd_result = (^fd -t f -H
        --exclude ".cache"
        --exclude ".pixi/cache"
        --exclude ".conda/pkgs"
        --size $"+($threshold_gb)G" . $home_path) | complete
    let files = if ($fd_result.exit_code == 0) {
        $fd_result.stdout | lines | where { |line| ($line | str length) > 0 }
    } else {
        []  # Return empty if fd fails
    }

    # Get file details for each found file
    $files
    | par-each { |file_path|
        try {
            let stat = (ls -l $file_path | first)
            {
                path: $file_path
                name: ($file_path | path basename)
                size_mb: ($stat.size / 1MB | math round)
                modified: $stat.modified
            }
        } catch {
            null  # Skip files we can't read
        }
    }
    | compact  # Remove nulls
    | sort-by size_mb -r
    | first 10
}

# Find pixi environments and check for old ones (>90 days unused)
def get-pixi-envs [username: string] {
    let cfg = (config)
    let home_path = $"($cfg.home_base)/($username)"

    if not ($home_path | path exists) {
        return {total: 0, old: 0, old_paths: []}
    }

    # Find all .pixi directories (project environments)
    let pixi_dirs_result = (^fd -H -t d "^\\.pixi$" $home_path | complete)

    if $pixi_dirs_result.exit_code != 0 or ($pixi_dirs_result.stdout | str length) == 0 {
        return {total: 0, old: 0, old_paths: []}
    }

    let pixi_dirs = ($pixi_dirs_result.stdout | lines | where { |line| ($line | str length) > 0 })
    let ninety_days_ago = ((date now) - 90day)

    # Check each .pixi directory for age
    let old_envs = $pixi_dirs | each { |pixi_dir|
        try {
            let modified = (ls -l $pixi_dir | first | get modified)
            if $modified < $ninety_days_ago {
                $pixi_dir
            } else {
                null
            }
        } catch {
            null
        }
    } | compact

    {
        total: ($pixi_dirs | length)
        old: ($old_envs | length)
        old_paths: $old_envs
    }
}

# Detect cleanup patterns in user's home directory (trash and caches)
def detect-patterns [username: string] {
    let cfg = (config)
    let home_path = $"($cfg.home_base)/($username)"

    if not ($home_path | path exists) {
        return {trash_mb: 0, caches: []}
    }

    # Check Trash directory size
    let trash_path = $"($home_path)/.local/share/Trash"
    let trash_mb = if ($trash_path | path exists) {
        try {
            (du $trash_path | get physical | first) / 1MB | math round
        } catch { 0 }
    } else { 0 }

    # Check for common cache directories that could be symlinked to /work
    let cache_dirs = [".cellpose", ".cache/huggingface", ".cache/uv", ".cache/rattler"]
    let found_caches = $cache_dirs | where { |d|
        ($"($home_path)/($d)" | path exists)
    }

    {trash_mb: $trash_mb, caches: $found_caches}
}

# Generate unified notification message
def generate-message [user: record, large_files: list, pixi_envs: record, patterns: record, over_quota: bool] {
    let cfg = (config)
    let hostname = (sys host).hostname

    # Show only top 3 files to keep it concise
    let top_files = $large_files | first 3
    let files_list = if ($top_files | is-empty) {
        ""
    } else {
        $top_files | each { |f| $"• ($f.size_mb)MB - ($f.path)" } | str join "\n"
    }

    let more_count = ($large_files | length) - 3
    let more_text = if $more_count > 0 { $" \(plus ($more_count) more\)" } else { "" }

    let subject = if $over_quota {
        $"⚠️ [($hostname)] ($user.user): ($user.size_gb)GB / ($cfg.soft_quota_gb)GB quota"
    } else {
        $"📁 [($hostname)] ($user.user): ($large_files | length) large files in /home"
    }

    # Build cleanup hints section
    let hints = (build-cleanup-hints $pixi_envs $patterns $user.user)

    let body = $"*($user.user)@($hostname)*: ($user.size_gb)GB used \(excludes .pixi/cache, .cache, .conda/pkgs\), ($large_files | length) files >($cfg.large_file_threshold_gb)GB

($files_list)($more_text)
($hints)
→ Move to `/work/users/($user.user)/`
───────────────────"

    {subject: $subject, body: $body}
}

# Build cleanup hints section from detected patterns
def build-cleanup-hints [pixi_envs: record, patterns: record, username: string] {
    mut hints = []

    # Trash hint (only if >100MB)
    if $patterns.trash_mb > 100 {
        $hints = ($hints | append $"• Trash: ($patterns.trash_mb)MB - `rm -rf ~/.local/share/Trash/*`")
    }

    # Pixi hint (from get-pixi-envs which finds ALL .pixi dirs)
    if $pixi_envs.old > 0 {
        let count = $pixi_envs.old
        $hints = ($hints | append $"• Old pixi envs \(($count) >90 days\): `pixi clean` in project dirs")
    }

    # Cache hint
    if ($patterns.caches | length) > 0 {
        let cache_list = ($patterns.caches | str join ", ")
        $hints = ($hints | append $"• Caches: Move ($cache_list) to /work/users/($username)/")
    }

    if ($hints | is-empty) {
        ""
    } else {
        $"\n:broom: *Cleanup hints*:\n" + ($hints | str join "\n") + "\n"
    }
}

# Send Slack notification via webhook
def send-slack [user: record, message_content: record, --dry-run] {
    let cfg = (config)
    let webhook_url = $cfg.slack_webhook_url  # Now only from env var

    if $dry_run {
        log "INFO" $"[DRY-RUN] Would send Slack notification for user ($user.user) - ($user.size_gb)GB used"
        print "--- Slack Message ---"
        print $message_content.subject
        print "---"
        print $message_content.body
        print "--- End Message ---"
    } else {
        if ($webhook_url | str length) == 0 {
            log "WARNING" "No Slack webhook URL configured. Set SLACK_WEBHOOK_URL environment variable"
            print "WARNING: Slack webhook not configured"
            print "Set SLACK_WEBHOOK_URL environment variable with your Slack webhook URL"
            print "Get webhook URL from: https://api.slack.com/messaging/webhooks"
            return
        }

        # Simple Slack message format for group channel
        let slack_payload = {
            text: $"($message_content.subject)\n($message_content.body)"
            mrkdwn: true
        }

        try {
            http post $webhook_url --content-type "application/json" $slack_payload
            log "INFO" $"Notified via Slack for user ($user.user) - ($user.size_gb)GB used"
        } catch {
            log "ERROR" "Failed to send Slack notification"
            print "ERROR: Failed to send Slack notification"
            print "Check your SLACK_WEBHOOK_URL is correct"
        }
    }
}

# Check a single user's quota
def check-user-quota [username: string, --dry-run, --verbose] {
    let cfg = (config)

    if $verbose {
        print $"Checking user: ($username)"
    }

    # Get usage
    let usage = (get-user-usage $username)

    if $usage == null {
        return {user: $username, status: "no_home", size_gb: 0, action: "none"}
    }

    # Check quotas, large files, pixi environments, and cleanup patterns
    let over_quota = $usage.size_gb > $cfg.soft_quota_gb
    let large_files = (get-large-files $username $cfg.large_file_threshold_gb)
    let has_large_files = ($large_files | length) > 0
    let pixi_envs = (get-pixi-envs $username)
    let patterns = (detect-patterns $username)

    # Determine if notification is needed
    if $over_quota or $has_large_files {
        let message_content = (generate-message $usage $large_files $pixi_envs $patterns $over_quota)
        let user_info = {
            user: $username
            status: "needs_action"
            size_gb: $usage.size_gb
            large_files: ($large_files | length)
            action: (if $over_quota { "quota_exceeded" } else { "has_large_files" })
        }
        send-slack $user_info $message_content --dry-run=$dry_run

        return $user_info
    } else {
        if $verbose {
            log "INFO" $"User ($username) is within quota - ($usage.size_gb)GB used and has no large files"
        }

        return {
            user: $username
            status: "ok"
            size_gb: $usage.size_gb
            large_files: 0
            action: "none"
        }
    }
}

# Main quota check function
def check-quotas [
    --dry-run           # Show what would be done without sending notifications
    --user: string      # Check specific user only
    --verbose           # Show detailed output
    --test              # Test mode (alias for --dry-run --verbose)
    --json              # Output results as JSON
] {
    let cfg = (config)
    let is_dry_run = $dry_run or $test
    let is_verbose = $verbose or $test

    log "INFO" "Starting quota check"

    # Get list of users to check
    let users_to_check = if ($user != null and ($user | str length) > 0) {
        [$user]
    } else {
        ls $cfg.home_base
        | where type == dir
        | get name
        | path basename
    }

    # Check each user (parallel for performance)
    let results = $users_to_check | par-each --threads 16 { |username|
        check-user-quota $username --dry-run=$is_dry_run --verbose=$is_verbose
    }

    # Summary
    let total_checked = ($results | where status != "no_home" | length)
    let needs_action = ($results | where status == "needs_action" | length)

    log "INFO" $"Quota check complete: ($total_checked) users checked, ($needs_action) need action"

    # Display summary table if verbose
    if $is_verbose and (not $json) {
        print ""
        print "=== Summary ==="
        $results
        | where status != "no_home"
        | select user size_gb status action
        | sort-by size_gb -r
        | table -e
    }

    # Output JSON if requested
    if $json {
        $results | to json | print
    }

    # Return results for potential further processing
    # Attach exit code for automation: non-zero if action needed
    let exit_code = if $needs_action > 0 { 2 } else { 0 }
    $results | each {|r| $r | insert exit_code $exit_code }
}

# Entry point
def main [
    --dry-run           # Show what would be done without sending notifications
    --user: string      # Check specific user only
    --verbose           # Show detailed output
    --test              # Test mode (equivalent to --dry-run --verbose)
    --json              # Output results as JSON
    --help              # Show help message
] {
    if $help {
        print "check-quotas.nu - Monitor home directory usage and notify users exceeding quotas"
        print ""
        print "Usage: nu check-quotas.nu [OPTIONS]"
        print ""
        print "Options:"
        print "  --dry-run    Show what would be done without sending Slack notifications"
        print "  --user USER  Check specific user only"
        print "  --verbose    Show detailed output"
        print "  --test       Test mode (same as --dry-run --verbose)"
        print "  --json       Output results as JSON"
        print "  --help       Show this help message"
        print ""
        print "Environment variables:"
        print "  HOME_BASE_DIR  Override home directory base (default: /home or /Users on macOS)"
        print "  QUOTA_GB       Override soft quota in GB (default: 100)"
        print "  SLACK_WEBHOOK_URL  Slack webhook URL for notifications"
        print ""
        print "Config file: ../config/quotas.yaml (relative to script location)"
        return
    }

    let results = (check-quotas --dry-run=$dry_run --user=$user --verbose=$verbose --test=$test --json=$json)

    # Exit with code so cron/CI can alert on needs_action
    let exit_code = ($results | first | get exit_code? | default 0)
    exit $exit_code
}
