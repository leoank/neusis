#!/usr/bin/env bash
# Test Suite for CSLab Infrastructure on Oppy
#
# Usage: sudo ./test-cslab-infrastructure.sh
#
# This script validates that all cslab infrastructure is working correctly:
# - imaging group and user membership
# - /work/* directory structure and permissions
# - Per-user directories with correct ownership
# - Monitoring timer and service configuration
# - Slack webhook secret accessibility

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED_TESTS=0
PASSED_TESTS=0

# Test result functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

section() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

# ============================================================
# Test 1: imaging Group Configuration
# ============================================================
section "Test 1: imaging Group Configuration"

# Check imaging group exists
if getent group imaging &>/dev/null; then
    pass "imaging group exists"

    # Check GID is 1000
    GID=$(getent group imaging | cut -d: -f3)
    if [[ "$GID" == "1000" ]]; then
        pass "imaging group has GID 1000"
    else
        fail "imaging group has wrong GID: $GID (expected 1000)"
    fi

    # Get members
    MEMBERS=$(getent group imaging | cut -d: -f4 | tr ',' '\n' | sort)
    MEMBER_COUNT=$(echo "$MEMBERS" | wc -l)

    if [[ $MEMBER_COUNT -ge 8 ]]; then
        pass "imaging group has $MEMBER_COUNT members"
    else
        fail "imaging group has only $MEMBER_COUNT members (expected 8+)"
    fi

    # List members
    echo "   Members: $(echo $MEMBERS | tr '\n' ' ')"
else
    fail "imaging group does not exist"
fi

# ============================================================
# Test 2: User Group Membership
# ============================================================
section "Test 2: User Group Membership"

# Test a few known users
for user in ank amunoz shsingh; do
    if id "$user" &>/dev/null; then
        if groups "$user" | grep -q imaging; then
            pass "User $user is in imaging group"
        else
            fail "User $user is NOT in imaging group"
        fi
    else
        warn "User $user does not exist (skipping)"
    fi
done

# ============================================================
# Test 3: /work/* Directory Structure
# ============================================================
section "Test 3: /work/* Directory Structure"

REQUIRED_DIRS=(
    "/work"
    "/work/datasets"
    "/work/users"
    "/work/scratch"
    "/work/tools"
    "/work/users/_archive"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        pass "Directory exists: $dir"

        # Check ownership (should be root:imaging)
        OWNER=$(stat -c '%U:%G' "$dir")
        if [[ "$OWNER" == "root:imaging" ]]; then
            pass "  Ownership correct: root:imaging"
        else
            fail "  Wrong ownership: $OWNER (expected root:imaging)"
        fi

        # Check permissions (should be 750)
        PERMS=$(stat -c '%a' "$dir")
        if [[ "$PERMS" == "750" ]]; then
            pass "  Permissions correct: 750"
        else
            fail "  Wrong permissions: $PERMS (expected 750)"
        fi
    else
        fail "Directory missing: $dir"
    fi
done

# ============================================================
# Test 4: Per-User Directories
# ============================================================
section "Test 4: Per-User Directories"

for user in ank amunoz shsingh; do
    if id "$user" &>/dev/null; then
        # Check /work/users/<user>
        USER_DIR="/work/users/$user"
        if [[ -d "$USER_DIR" ]]; then
            pass "User directory exists: $USER_DIR"

            OWNER=$(stat -c '%U:%G' "$USER_DIR")
            if [[ "$OWNER" == "$user:imaging" ]]; then
                pass "  Ownership correct: $user:imaging"
            else
                fail "  Wrong ownership: $OWNER (expected $user:imaging)"
            fi

            PERMS=$(stat -c '%a' "$USER_DIR")
            if [[ "$PERMS" == "750" ]]; then
                pass "  Permissions correct: 750"
            else
                fail "  Wrong permissions: $PERMS (expected 750)"
            fi
        else
            fail "User directory missing: $USER_DIR"
        fi

        # Check /work/scratch/<user>
        SCRATCH_DIR="/work/scratch/$user"
        if [[ -d "$SCRATCH_DIR" ]]; then
            pass "Scratch directory exists: $SCRATCH_DIR"
        else
            fail "Scratch directory missing: $SCRATCH_DIR"
        fi
    fi
done

# ============================================================
# Test 5: Directory Access Permissions
# ============================================================
section "Test 5: Directory Access Permissions (Functional)"

# Test as a specific user if we can write
if id ank &>/dev/null; then
    TEST_FILE="/work/users/ank/.test-write-$$"
    if sudo -u ank touch "$TEST_FILE" 2>/dev/null; then
        pass "User ank can write to /work/users/ank/"
        sudo rm -f "$TEST_FILE"
    else
        fail "User ank CANNOT write to /work/users/ank/"
    fi

    # Test group read access (another imaging member should read ank's dir)
    if id amunoz &>/dev/null; then
        if sudo -u amunoz ls /work/users/ank/ &>/dev/null; then
            pass "User amunoz (imaging group) can read /work/users/ank/"
        else
            fail "User amunoz (imaging group) CANNOT read /work/users/ank/"
        fi
    fi
fi

# ============================================================
# Test 6: Systemd Timer Configuration
# ============================================================
section "Test 6: Systemd Timer Configuration"

if systemctl list-timers cslab-check-quotas.timer &>/dev/null; then
    pass "cslab-check-quotas.timer exists"

    # Check if timer is active
    if systemctl is-active cslab-check-quotas.timer &>/dev/null; then
        pass "Timer is active"
    else
        fail "Timer is NOT active"
    fi

    # Check schedule
    NEXT_RUN=$(systemctl status cslab-check-quotas.timer | grep "Trigger:" | awk '{print $2, $3, $4}')
    if [[ -n "$NEXT_RUN" ]]; then
        pass "Timer scheduled for: $NEXT_RUN"
    else
        fail "Timer has no next run scheduled"
    fi

    # Check if it's set for Monday 9 AM
    CALENDAR=$(systemctl cat cslab-check-quotas.timer | grep OnCalendar | awk '{print $2}')
    if [[ "$CALENDAR" == "Mon *-*-* 09:00:00" ]]; then
        pass "Schedule correct: Monday 9:00 AM"
    else
        warn "Schedule may be different: $CALENDAR"
    fi
else
    fail "cslab-check-quotas.timer does not exist"
fi

# ============================================================
# Test 7: Systemd Service Configuration
# ============================================================
section "Test 7: Systemd Service Configuration"

if systemctl cat cslab-check-quotas.service &>/dev/null; then
    pass "cslab-check-quotas.service exists"

    # Check if service can be started (dry run check)
    if systemctl list-unit-files cslab-check-quotas.service | grep -q cslab-check-quotas.service; then
        pass "Service is registered in systemd"
    else
        fail "Service NOT registered in systemd"
    fi

    # Check script wrapper exists (NixOS wraps the script)
    SCRIPT_WRAPPER=$(systemctl cat cslab-check-quotas.service | grep ExecStart | awk '{print $1}' | cut -d= -f2)
    if [[ -n "$SCRIPT_WRAPPER" ]] && [[ -f "$SCRIPT_WRAPPER" ]]; then
        pass "Service wrapper script exists"

        # Extract actual script path from wrapper
        ACTUAL_SCRIPT=$(grep -o '/nix/store/[^/]*-check-quotas.nu' "$SCRIPT_WRAPPER" 2>/dev/null | head -1)
        if [[ -n "$ACTUAL_SCRIPT" ]] && [[ -f "$ACTUAL_SCRIPT" ]]; then
            pass "  Monitoring script exists: $(basename $ACTUAL_SCRIPT)"
        else
            warn "  Could not verify check-quotas.nu in wrapper"
        fi
    else
        fail "Service wrapper script NOT found"
    fi

    # Check SuccessExitStatus includes 2
    if systemctl cat cslab-check-quotas.service | grep -q "SuccessExitStatus.*2"; then
        pass "SuccessExitStatus includes code 2 (user needs action)"
    else
        fail "SuccessExitStatus does NOT include code 2"
    fi
else
    fail "cslab-check-quotas.service does not exist"
fi

# ============================================================
# Test 8: Secrets Configuration
# ============================================================
section "Test 8: Secrets Configuration"

# Check if slack webhook secret exists in agenix
if [[ -f "/run/agenix/slack_webhook" ]]; then
    pass "Slack webhook secret deployed to /run/agenix/slack_webhook"

    # Check permissions (should be 400, root-only)
    PERMS=$(stat -c '%a' "/run/agenix/slack_webhook")
    if [[ "$PERMS" == "400" ]]; then
        pass "  Secret permissions correct: 400"
    else
        fail "  Secret permissions wrong: $PERMS (expected 400)"
    fi

    OWNER=$(stat -c '%U:%G' "/run/agenix/slack_webhook")
    if [[ "$OWNER" == "root:root" ]]; then
        pass "  Secret ownership correct: root:root"
    else
        fail "  Secret ownership wrong: $OWNER (expected root:root)"
    fi

    # Check secret is not empty
    if [[ -s "/run/agenix/slack_webhook" ]]; then
        pass "  Secret file is not empty"

        # Check it looks like a Slack webhook URL (without revealing it)
        if grep -q "hooks.slack.com" "/run/agenix/slack_webhook" 2>/dev/null; then
            pass "  Secret contains Slack webhook URL"
        else
            warn "  Secret does not appear to be a Slack webhook"
        fi
    else
        fail "  Secret file is empty"
    fi
else
    fail "Slack webhook secret NOT deployed (expected /run/agenix/slack_webhook)"
fi

# ============================================================
# Test 9: Log Directory
# ============================================================
section "Test 9: Log Directory"

LOG_DIR="/var/log/lab-scripts"
if [[ -d "$LOG_DIR" ]]; then
    pass "Log directory exists: $LOG_DIR"

    LOG_FILE="$LOG_DIR/check-quotas.log"
    if [[ -f "$LOG_FILE" ]]; then
        pass "Log file exists: $LOG_FILE"

        # Check if it has recent entries
        if [[ -s "$LOG_FILE" ]]; then
            LAST_RUN=$(tail -1 "$LOG_FILE" | grep -o '\[.*\]' | head -1)
            pass "  Last log entry: $LAST_RUN"
        else
            warn "  Log file is empty (may not have run yet)"
        fi
    else
        warn "Log file not created yet: $LOG_FILE"
    fi
else
    fail "Log directory does not exist: $LOG_DIR"
fi

# ============================================================
# Test 10: Sudo Access Restriction
# ============================================================
section "Test 10: Sudo Access Restriction"

# Admins should have wheel group (sudo access)
ADMINS=(ank amunoz shsingh)
for user in "${ADMINS[@]}"; do
    if id "$user" &>/dev/null; then
        if groups "$user" | grep -q wheel; then
            pass "Admin $user has sudo access (wheel group)"
        else
            fail "Admin $user does NOT have wheel group"
        fi
    else
        warn "Admin $user does not exist (skipping)"
    fi
done

# Regulars should NOT have wheel group
REGULARS=(spathak jewald rshen jfredinh)
for user in "${REGULARS[@]}"; do
    if id "$user" &>/dev/null; then
        if groups "$user" | grep -q wheel; then
            fail "Regular user $user has sudo access (should NOT have wheel group)"
        else
            pass "Regular user $user does NOT have sudo access (correct)"
        fi
    else
        warn "Regular user $user does not exist (skipping)"
    fi
done

# ============================================================
# Test 11: Locked User Accounts
# ============================================================
section "Test 11: Locked User Accounts"

# Test locked users (accounts that exist but cannot login)
LOCKED_USERS=(ngogober)
for user in "${LOCKED_USERS[@]}"; do
    if id "$user" &>/dev/null; then
        pass "Locked user $user exists"

        # Check shell is nologin
        USER_SHELL=$(getent passwd "$user" | cut -d: -f7)
        if [[ "$USER_SHELL" == *"nologin"* ]]; then
            pass "  User $user has nologin shell: $USER_SHELL"
        else
            fail "  User $user has wrong shell: $USER_SHELL (expected nologin)"
        fi

        # Check password status (nologin shell is what prevents login, password is secondary)
        SHADOW_FIELD=$(sudo grep "^$user:" /etc/shadow 2>/dev/null | cut -d: -f2)
        if [[ "$SHADOW_FIELD" == "!" ]] || [[ "$SHADOW_FIELD" == "*" ]]; then
            pass "  User $user has locked password"
        elif [[ "$SHADOW_FIELD" == "\$"* ]]; then
            warn "  User $user has hashed password (login blocked by nologin shell)"
        else
            warn "  Could not verify password status for $user"
        fi

        # Check still in imaging group (for data access)
        if groups "$user" | grep -q imaging; then
            pass "  User $user is in imaging group (data accessible to admins)"
        else
            fail "  User $user is NOT in imaging group"
        fi

        # Check NOT in wheel group
        if groups "$user" | grep -q wheel; then
            fail "  Locked user $user still has sudo access (wheel group)"
        else
            pass "  User $user does NOT have sudo access (correct)"
        fi
    else
        warn "Locked user $user does not exist (may not be deployed yet)"
    fi
done

# ============================================================
# Test 12: Group Membership Monitoring
# ============================================================
section "Test 12: Group Membership Monitoring"

if systemctl list-timers cslab-check-groups.timer &>/dev/null; then
    pass "cslab-check-groups.timer exists"

    # Check if timer is active
    if systemctl is-active cslab-check-groups.timer &>/dev/null; then
        pass "Timer is active"
    else
        fail "Timer is NOT active"
    fi

    # Check schedule
    NEXT_RUN=$(systemctl status cslab-check-groups.timer | grep "Trigger:" | awk '{print $2, $3, $4}')
    if [[ -n "$NEXT_RUN" ]]; then
        pass "Timer scheduled for: $NEXT_RUN"
    else
        fail "Timer has no next run scheduled"
    fi

    # Check if it's set for Wednesday 9 AM
    CALENDAR=$(systemctl cat cslab-check-groups.timer | grep OnCalendar | awk '{print $2}')
    if [[ "$CALENDAR" == "Wed *-*-* 09:00:00" ]]; then
        pass "Schedule correct: Wednesday 9:00 AM"
    else
        warn "Schedule may be different: $CALENDAR"
    fi
else
    fail "cslab-check-groups.timer does not exist"
fi

if systemctl cat cslab-check-groups.service &>/dev/null; then
    pass "cslab-check-groups.service exists"

    # Check SuccessExitStatus includes 2
    if systemctl cat cslab-check-groups.service | grep -q "SuccessExitStatus.*2"; then
        pass "SuccessExitStatus includes code 2 (violations found)"
    else
        fail "SuccessExitStatus does NOT include code 2"
    fi
else
    fail "cslab-check-groups.service does not exist"
fi

# ============================================================
# Test 13: Manual Service Execution
# ============================================================
section "Test 13: Manual Service Execution (Optional)"

echo "To manually test the quota check service, run:"
echo "  sudo systemctl start cslab-check-quotas.service"
echo "  sudo systemctl status cslab-check-quotas.service"
echo "  sudo journalctl -u cslab-check-quotas.service -n 20"
echo ""
echo "To manually test the group check service, run:"
echo "  sudo systemctl start cslab-check-groups.service"
echo "  sudo systemctl status cslab-check-groups.service"
echo "  sudo journalctl -u cslab-check-groups.service -n 20"
echo ""
echo "Expected: Services complete successfully, Slack notifications sent if issues found"

# ============================================================
# Summary
# ============================================================
section "Test Summary"

TOTAL_TESTS=$((PASSED_TESTS + FAILED_TESTS))

echo "Passed: $PASSED_TESTS / $TOTAL_TESTS"
echo "Failed: $FAILED_TESTS / $TOTAL_TESTS"

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC} ✓"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC} See above for details."
    exit 1
fi
