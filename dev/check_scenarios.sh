#!/usr/bin/env bash
## Run the installed-package test suite across the release-blocking scenarios.
##
## Usage:
##   bash dev/check_scenarios.sh <source tree> <nonexistent output directory>
##
## RA_NOLD_R names the R executable built without extended long doubles. Its
## local default is /home/josemgomezj/.local/opt/R-4.6.1-noLD/bin/R. The
## companion Rscript and lib-rmpfr directory are resolved from that path.

set -u
export LC_ALL=C LC_NUMERIC=C

SOURCE_TREE=${1:?source tree}
OUTPUT_DIR=${2:?nonexistent output directory}
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
SCENARIO_DIR="$SCRIPT_DIR/scenarios"
RA_NOLD_R=${RA_NOLD_R:-/home/josemgomezj/.local/opt/R-4.6.1-noLD/bin/R}
NOLD_BIN=$(dirname "$RA_NOLD_R")
NOLD_ROOT=$(dirname "$NOLD_BIN")
NOLD_RSCRIPT="$NOLD_BIN/Rscript"
NOLD_MPFR_LIB="$NOLD_ROOT/lib-rmpfr"

fail_setup() {
  echo "SCENARIOS FAILURE setup=$1"
  echo "SCENARIOS FAIL"
  exit 1
}

incomplete() {
  echo "SCENARIOS MISSING $1"
  echo "SCENARIOS INCOMPLETE"
  exit 3
}

if [ -e "$OUTPUT_DIR" ]; then
  fail_setup "output directory already exists: $OUTPUT_DIR"
fi
if [ ! -f "$SOURCE_TREE/DESCRIPTION" ]; then
  fail_setup "source tree has no DESCRIPTION: $SOURCE_TREE"
fi
if [ ! -f "$SCENARIO_DIR/hook_scenario.R" ] ||
   [ ! -f "$SCENARIO_DIR/probe_scenario.R" ]; then
  fail_setup "scenario support files are absent from $SCENARIO_DIR"
fi
if ! command -v R >/dev/null 2>&1; then incomplete "system R"; fi
if ! command -v Rscript >/dev/null 2>&1; then incomplete "system Rscript"; fi
if [ ! -x "$RA_NOLD_R" ]; then incomplete "R without long double: $RA_NOLD_R"; fi
if [ ! -x "$NOLD_RSCRIPT" ]; then incomplete "Rscript without long double: $NOLD_RSCRIPT"; fi
if [ ! -d "$NOLD_MPFR_LIB" ]; then incomplete "Rmpfr library for R without long double: $NOLD_MPFR_LIB"; fi

mkdir -p "$OUTPUT_DIR/build" "$OUTPUT_DIR/lib_sys" "$OUTPUT_DIR/lib_nold" \
  "$OUTPUT_DIR/empty_user_lib" || fail_setup "cannot create output directories"

system_missing=$(Rscript --vanilla -e '
  need <- c("testthat", "Rmpfr")
  cat(paste(need[!vapply(need, requireNamespace, logical(1L), quietly = TRUE)],
            collapse = ","))
' 2>&1)
if [ -n "$system_missing" ]; then
  incomplete "system R libraries: $system_missing"
fi

nold_missing=$(env "R_LIBS=$NOLD_MPFR_LIB" \
  "R_LIBS_USER=$OUTPUT_DIR/empty_user_lib" "$NOLD_RSCRIPT" --vanilla -e '
  need <- c("testthat", "Rmpfr")
  cat(paste(need[!vapply(need, requireNamespace, logical(1L), quietly = TRUE)],
            collapse = ","))
' 2>&1)
if [ -n "$nold_missing" ]; then
  incomplete "R-without-long-double libraries: $nold_missing"
fi

cd "$OUTPUT_DIR/build" || fail_setup "cannot enter build directory"
R CMD build --no-manual "$SOURCE_TREE" > build.log 2>&1 ||
  fail_setup "R CMD build; log=$OUTPUT_DIR/build/build.log"
TARBALL=$(ls RobustArithmetic_*.tar.gz)
if [ -z "$TARBALL" ] || [ ! -f "$TARBALL" ]; then
  fail_setup "source tarball was not produced"
fi
tar xzf "$TARBALL" || fail_setup "cannot unpack $TARBALL"
R CMD INSTALL --library="$OUTPUT_DIR/lib_sys" "$TARBALL" > install_sys.log 2>&1 ||
  fail_setup "system-R install; log=$OUTPUT_DIR/build/install_sys.log"
env "R_LIBS_USER=$OUTPUT_DIR/empty_user_lib" "$RA_NOLD_R" CMD INSTALL \
  --library="$OUTPUT_DIR/lib_nold" "$TARBALL" > install_nold.log 2>&1 ||
  fail_setup "R-without-long-double install; log=$OUTPUT_DIR/build/install_nold.log"
echo "SCENARIOS tarball=$TARBALL sha256=$(sha256sum "$TARBALL" | cut -d' ' -f1)"

bad=0
ran=0

run_scenario() {
  local name=$1
  local rscript=$2
  local libraries=$3
  local user_library=$4
  local emulation=$5
  local expected_mpfr=$6
  local expected_degraded=$7
  local expected_mismatch=$8
  local expected_solve=$9
  local run_dir="$OUTPUT_DIR/run_$name"
  local code summary failures probe probe_code mismatch verdict

  mkdir -p "$run_dir" &&
    cp -r "$OUTPUT_DIR/build/RobustArithmetic/tests/." "$run_dir/" ||
    fail_setup "cannot prepare scenario $name"

  local environment=(-u NOT_CRAN "R_LIBS=$libraries"
    "R_PROFILE_USER=$SCENARIO_DIR/hook_scenario.R" "RA_SCENARIO=$emulation")
  if [ -n "$user_library" ]; then
    environment+=("R_LIBS_USER=$user_library")
  fi

  (cd "$run_dir" && env "${environment[@]}" "$rscript" testthat.R \
    > testthat.Rout 2>&1)
  code=$?
  ran=$((ran + 1))
  summary=$(grep -o '\[ FAIL [0-9]* | WARN [0-9]* | SKIP [0-9]* | PASS [0-9]* \]' \
    "$run_dir/testthat.Rout" | tail -n 1)
  failures=$(grep -E '^(──|--) (Failure|Error) ' "$run_dir/testthat.Rout" |
    sed -E -e 's/^(──|--) //' -e 's/ (─+|-+)$//' | tr '\n' ';')

  (cd "$run_dir" && env "${environment[@]}" "$rscript" \
    "$SCENARIO_DIR/probe_scenario.R" > probe.log 2>&1)
  probe_code=$?
  probe=$(grep '^PROBE' "$run_dir/probe.log" | tail -n 1)
  mismatch=$(printf '%s' "$probe" | sed -n 's/.* mismatch=\([0-9]*\) .*/\1/p')
  verdict=OK

  [ -n "$summary" ] || verdict=BAD
  printf '%s' "$summary" | grep -q '^\[ FAIL 0 ' || verdict=BAD
  [ "$code" -eq 0 ] || verdict=BAD
  [ "$probe_code" -eq 0 ] || verdict=BAD
  printf '%s' "$probe" | grep -q " lib=$OUTPUT_DIR/lib_" || verdict=BAD
  printf '%s' "$probe" | grep -q \
    " has_mpfr=$expected_mpfr degraded=$expected_degraded " || verdict=BAD
  printf '%s' "$probe" | grep -q " solve=$expected_solve$" || verdict=BAD
  if [ "$expected_mismatch" = positive ]; then
    [ -n "$mismatch" ] && [ "$mismatch" -gt 0 ] || verdict=BAD
  fi

  echo "SCENARIO $name exit=$code summary=${summary:-NONE} probe_exit=$probe_code ${probe:-PROBE NONE} verdict=$verdict"
  if [ "$verdict" = BAD ]; then
    bad=$((bad + 1))
    if [ -n "$failures" ]; then
      echo "SCENARIO_FAILURE $name $failures"
    else
      echo "SCENARIO_FAILURE $name test=UNKNOWN log=$run_dir/testthat.Rout"
    fi
  fi
}

SYSTEM_RSCRIPT=Rscript
run_scenario home_sys "$SYSTEM_RSCRIPT" "$OUTPUT_DIR/lib_sys" "" \
  home TRUE FALSE any returned
run_scenario anchor_sys "$SYSTEM_RSCRIPT" "$OUTPUT_DIR/lib_sys" "" \
  anchor TRUE FALSE positive returned
run_scenario windows_sys "$SYSTEM_RSCRIPT" "$OUTPUT_DIR/lib_sys" "" \
  windows TRUE TRUE positive returned
run_scenario loaddeg_sys "$SYSTEM_RSCRIPT" "$OUTPUT_DIR/lib_sys" "" \
  load_degraded TRUE TRUE positive returned
run_scenario home_nold_mpfr "$NOLD_RSCRIPT" \
  "$OUTPUT_DIR/lib_nold:$NOLD_MPFR_LIB" "$OUTPUT_DIR/empty_user_lib" \
  home TRUE FALSE any returned
run_scenario windows_nold_mpfr "$NOLD_RSCRIPT" \
  "$OUTPUT_DIR/lib_nold:$NOLD_MPFR_LIB" "$OUTPUT_DIR/empty_user_lib" \
  windows TRUE TRUE positive returned
run_scenario anchor_nold_nompfr "$NOLD_RSCRIPT" "$OUTPUT_DIR/lib_nold" \
  "$OUTPUT_DIR/empty_user_lib" anchor FALSE FALSE positive returned
run_scenario loaddeg_nold_nompfr "$NOLD_RSCRIPT" "$OUTPUT_DIR/lib_nold" \
  "$OUTPUT_DIR/empty_user_lib" load_degraded FALSE TRUE positive refused

if [ "$ran" -ne 8 ]; then
  echo "SCENARIOS FAILURE ran=$ran expected=8"
  echo "SCENARIOS FAIL"
  exit 1
fi
if [ "$bad" -ne 0 ]; then
  echo "SCENARIOS FAILURE bad=$bad ran=$ran"
  echo "SCENARIOS FAIL"
  exit 1
fi
echo "SCENARIOS PASS"
exit 0
