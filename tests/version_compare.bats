#!/usr/bin/env bats
#
# Tests for proton_version_lt, the dotted-version comparison behind the glibc
# check that guards TKG installs.
#
# This replaced a `bc` comparison, which was wrong twice over:
#
#   1. bc treats "2.4" as the decimal 2.4, so it reported glibc 2.4, 2.5 and
#      2.9 as NEWER than the required 2.33 - the guard never fired for systems
#      that genuinely could not run the build.
#   2. bc was never declared as a dependency, so on a system without it the
#      comparison produced an empty string and the guard silently skipped.

setup() {
    PCU_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export PCU_LIB_ONLY=1
    # shellcheck source=/dev/null
    source "$PCU_ROOT/proton-community-updater.sh"
}

@test "a lower minor version is older" {
    run proton_version_lt "2.28" "2.33"
    [ "$status" -eq 0 ]
}

@test "a higher minor version is not older" {
    run proton_version_lt "2.42" "2.33"
    [ "$status" -ne 0 ]
}

@test "single-digit minors compare as versions, not decimals" {
    # The bc bug: 2.4 < 2.33 as versions, but 2.4 > 2.33 as decimals.
    run proton_version_lt "2.4" "2.33"
    [ "$status" -eq 0 ]
    run proton_version_lt "2.9" "2.33"
    [ "$status" -eq 0 ]
    run proton_version_lt "2.5" "2.33"
    [ "$status" -eq 0 ]
}

@test "equal versions are not older" {
    run proton_version_lt "2.33" "2.33"
    [ "$status" -ne 0 ]
}

@test "a differing major version dominates" {
    run proton_version_lt "1.99" "2.33"
    [ "$status" -eq 0 ]
    run proton_version_lt "3.0" "2.33"
    [ "$status" -ne 0 ]
}

@test "three-component versions are handled" {
    run proton_version_lt "2.33.1" "2.34"
    [ "$status" -eq 0 ]
    run proton_version_lt "2.34" "2.33.1"
    [ "$status" -ne 0 ]
}

@test "the comparison does not depend on bc being installed" {
    run bash -c "PCU_LIB_ONLY=1; source '$PCU_ROOT/proton-community-updater.sh'; PATH=/usr/bin:/bin; unset -f bc 2>/dev/null; proton_version_lt 2.4 2.33"
    [ "$status" -eq 0 ]
}

@test "missing arguments are rejected rather than silently passing" {
    run proton_version_lt "2.33"
    [ "$status" -ne 0 ]
    run proton_version_lt
    [ "$status" -ne 0 ]
}
