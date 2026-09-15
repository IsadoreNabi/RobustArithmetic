#!/usr/bin/env bash

set -eu
export LC_ALL=C

if [ "$#" -ne 3 ]; then
  printf 'usage: import.sh <archive> <LICENSE> <output>\n' >&2
  exit 2
fi

archive=$1
license=$2
output=$3
script_dir=$(dirname "$(readlink -f "$0")")
manifest=$script_dir/FILES

[ -f "$archive" ] || { printf 'archive not found: %s\n' "$archive" >&2; exit 2; }
[ -f "$license" ] || { printf 'license not found: %s\n' "$license" >&2; exit 2; }
[ -f "$manifest" ] || { printf 'manifest not found: %s\n' "$manifest" >&2; exit 2; }
[ ! -e "$output" ] || { printf 'output already exists: %s\n' "$output" >&2; exit 2; }

archive_sha=$(sha256sum "$archive" | cut -d' ' -f1)
license_sha=$(sha256sum "$license" | cut -d' ' -f1)
[ "$archive_sha" = 52f35d1029a6c6423f8c537f59164b2359cffe98c1ca2079ea55caf5d1820ce5 ] || {
  printf 'unexpected archive SHA-256: %s\n' "$archive_sha" >&2
  exit 2
}
[ "$license_sha" = 81830875362f4d477637de58eecd6d458db108cc90c40904fca3694807b86de3 ] || {
  printf 'unexpected license SHA-256: %s\n' "$license_sha" >&2
  exit 2
}

archive_root=$(tar tzf "$archive" 2>/dev/null | head -n 1)
case "$archive_root" in
  */) ;;
  *) printf 'archive has no single directory root\n' >&2; exit 2 ;;
esac

mkdir -p "$output"
while IFS=$'\t' read -r repo_path upstream_path; do
  [ -n "$repo_path" ] || continue
  case "$repo_path" in
    /*|*..*) printf 'unsafe repository path: %s\n' "$repo_path" >&2; exit 2 ;;
  esac
  case "$upstream_path" in
    /*|*..*) printf 'unsafe upstream path: %s\n' "$upstream_path" >&2; exit 2 ;;
  esac

  destination=$output/$repo_path
  mkdir -p "$(dirname "$destination")"
  if [ "$upstream_path" = LICENSE ]; then
    cp "$license" "$destination"
    continue
  fi

  function_name=$(basename "$(dirname "$upstream_path")")
  case "$upstream_path" in
    */dint.h)
      guard=$(printf '%s' "$function_name" | tr '[:lower:]' '[:upper:]')
      tar xOzf "$archive" "${archive_root}${upstream_path}" |
        sed -e "s/DINT_H/RA_COREMATH_${guard}_DINT_H/g" \
            -e "s/UINT128_T/RA_COREMATH_${guard}_UINT128_T/g" \
            -e 's/^typedef unsigned _BitInt(128) u128;$/__extension__ typedef unsigned _BitInt(128) u128;/' \
        > "$destination"
      ;;
    *.c)
      tar xOzf "$archive" "${archive_root}${upstream_path}" |
        sed -e '1i\
#include "ra_portable_math.h"' \
            -e '/^\/\/ Warning: clang also defines __GNUC__$/,/^#endif$/d' \
            -e 's/^#pragma STDC FENV_ACCESS ON$/\/\* STDC FENV_ACCESS is intentionally not requested in this vendored build. \*\//' \
            -e 's/^typedef unsigned _BitInt(128) u128;$/__extension__ typedef unsigned _BitInt(128) u128;/' \
            -e "s/cr_${function_name}/ra_cr_${function_name}/g" \
            -e "s/#include \"dint.h\"/#include \"coremath_${function_name}_dint.h\"/" \
            -e 's/__builtin_fma/ra_fma/g' \
            -e '/^\/\* __builtin_roundeven was introduced in gcc 10:$/,/^#endif$/c\
#define roundeven_finite(x) ra_roundeven_finite (x)' \
        > "$destination"
      ;;
    *) printf 'unsupported manifest entry: %s\n' "$upstream_path" >&2; exit 2 ;;
  esac
done < "$manifest"
