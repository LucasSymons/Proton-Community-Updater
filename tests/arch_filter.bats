#!/usr/bin/env bats
#
# Tests for proton_filter_by_arch, the architecture filter applied to the list
# of downloadable Proton builds.
#
# The fixture in tests/fixtures/release_assets.txt holds real asset names
# captured from the GloriousEggroll and TKG release APIs. It deliberately spans
# all three GE naming eras, because the arch suffix is a recent addition:
#
#   GE-Proton11-4 and newer   both "-x86_64" and "-aarch64" suffixes
#   GE-Proton11-1 .. 11-3     "-aarch64" suffix, x86_64 build left unsuffixed
#   GE-Proton11-2 and older   no suffix at all, x86_64 only
#
# An unsuffixed asset is therefore an x86_64 build, not an unknown one.

setup() {
    PCU_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    FIXTURES="$PCU_ROOT/tests/fixtures/release_assets.txt"

    # Load the script for its functions without starting the interactive program
    export PCU_LIB_ONLY=1
    # shellcheck source=/dev/null
    source "$PCU_ROOT/proton-community-updater.sh"

    mapfile -t assets < "$FIXTURES"
}

# Assert that the captured output contains the given line, matched in full
assert_line_present() {
    if ! printf '%s\n' "$output" | grep -qxF "$1"; then
        printf 'expected output to contain the line: %s\n' "$1" >&2
        return 1
    fi
}

# Assert that the captured output does not contain the given line
assert_line_absent() {
    if printf '%s\n' "$output" | grep -qxF "$1"; then
        printf 'expected output NOT to contain the line: %s\n' "$1" >&2
        return 1
    fi
}

@test "x86_64 filter keeps builds carrying an explicit x86_64 suffix" {
    run proton_filter_by_arch "x86_64" "${assets[@]}"
    [ "$status" -eq 0 ]
    assert_line_present "GE-Proton11-5-x86_64.tar.gz"
    assert_line_present "GE-Proton11-4-x86_64.tar.gz"
}

@test "x86_64 filter keeps legacy builds that carry no arch suffix" {
    # The regression that matters: a naive grep for x86_64 would hide every
    # build older than GE-Proton11-4, which is nearly the whole list.
    run proton_filter_by_arch "x86_64" "${assets[@]}"
    [ "$status" -eq 0 ]
    assert_line_present "GE-Proton11-3.tar.gz"
    assert_line_present "GE-Proton11-2.tar.gz"
    assert_line_present "GE-Proton10-34.tar.gz"
}

@test "x86_64 filter drops aarch64 builds" {
    run proton_filter_by_arch "x86_64" "${assets[@]}"
    [ "$status" -eq 0 ]
    assert_line_absent "GE-Proton11-5-aarch64.tar.gz"
    assert_line_absent "GE-Proton11-1-aarch64.tar.gz"
    [ "$(printf '%s\n' "$output" | grep -c 'aarch64')" -eq 0 ]
}

@test "aarch64 filter keeps builds carrying an explicit aarch64 suffix" {
    run proton_filter_by_arch "aarch64" "${assets[@]}"
    [ "$status" -eq 0 ]
    assert_line_present "GE-Proton11-5-aarch64.tar.gz"
    assert_line_present "GE-Proton11-1-aarch64.tar.gz"
}

@test "aarch64 filter drops unsuffixed builds because they are not ARM" {
    run proton_filter_by_arch "aarch64" "${assets[@]}"
    [ "$status" -eq 0 ]
    assert_line_absent "GE-Proton11-3.tar.gz"
    assert_line_absent "GE-Proton10-34.tar.gz"
    # Every surviving line must be an aarch64 build
    [ "$(printf '%s\n' "$output" | grep -vc 'aarch64')" -eq 0 ]
}

@test "x86_64 filter drops a recognised non-x86 architecture" {
    # A hypothetical future build must not fall through into the x86_64 bucket
    run proton_filter_by_arch "x86_64" \
        "GE-Proton11-9-x86_64.tar.gz" \
        "GE-Proton11-9-riscv64.tar.gz" \
        "GE-Proton11-9-ppc64le.tar.gz"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [ "${lines[0]}" = "GE-Proton11-9-x86_64.tar.gz" ]
}

@test "all filter returns every input unchanged" {
    run proton_filter_by_arch "all" "${assets[@]}"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq "${#assets[@]}" ]
    [ "${lines[0]}" = "${assets[0]}" ]
    [ "${lines[${#lines[@]}-1]}" = "${assets[${#assets[@]}-1]}" ]
}

@test "filtering preserves the newest-first input order" {
    run proton_filter_by_arch "x86_64" "${assets[@]}"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "GE-Proton11-5-x86_64.tar.gz" ]

    newer="$(printf '%s\n' "$output" | grep -nxF "GE-Proton11-2.tar.gz" | cut -d: -f1)"
    older="$(printf '%s\n' "$output" | grep -nxF "GE-Proton10-34.tar.gz" | cut -d: -f1)"
    [ -n "$newer" ] && [ -n "$older" ]
    [ "$newer" -lt "$older" ]
}

@test "empty input produces no output and no error" {
    run proton_filter_by_arch "x86_64"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "an unrecognised filter is rejected rather than passing everything through" {
    run proton_filter_by_arch "sparc" "GE-Proton11-5-x86_64.tar.gz"
    [ "$status" -ne 0 ]
    assert_line_absent "GE-Proton11-5-x86_64.tar.gz"
}

@test "TKG asset names survive an x86_64 filter" {
    run proton_filter_by_arch "x86_64" "${assets[@]}"
    [ "$status" -eq 0 ]
    assert_line_present "proton_tkg_7.6.r12.g51472395.release.tar.gz"
}
