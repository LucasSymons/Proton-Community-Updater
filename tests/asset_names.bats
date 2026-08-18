#!/usr/bin/env bats
#
# Tests for proton_asset_names, which turns a GitHub releases API response into
# the list of installable archive filenames.
#
# Every release ships a .sha512sum next to each archive. Those must be dropped,
# or they end up in the install menu as builds that cannot be installed.

setup() {
    PCU_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    FIXTURE="$PCU_ROOT/tests/fixtures/releases_api.txt"

    export PCU_LIB_ONLY=1
    # shellcheck source=/dev/null
    source "$PCU_ROOT/proton-community-updater.sh"
}

@test "checksum assets are dropped from the asset list" {
    run proton_asset_names < "$FIXTURE"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c 'sha512sum')" -eq 0 ]
}

@test "archive assets survive and are reduced to bare filenames" {
    run proton_asset_names < "$FIXTURE"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
    printf '%s\n' "$output" | grep -qxF "GE-Proton11-5-x86_64.tar.gz"
    printf '%s\n' "$output" | grep -qxF "GE-Proton11-5-aarch64.tar.gz"
}

@test "no URL fragments or quotes leak into the names" {
    run proton_asset_names < "$FIXTURE"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c 'https\|/\|\"')" -eq 0 ]
}

@test "empty input yields no output and no error" {
    # A rate-limited or failed API call produces nothing; that must not make
    # basename complain about a missing operand.
    run bash -c "PCU_LIB_ONLY=1; source '$PCU_ROOT/proton-community-updater.sh'; proton_asset_names </dev/null"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "the checksum filter is a valid POSIX regex" {
    # "*.sha512sum" is malformed: GNU grep only warns, stricter greps reject it
    # outright and the whole build listing fails.
    run bash -c "grep -vE '\\.sha512sum' < '$FIXTURE'"
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c 'warning')" -eq 0 ]
}
