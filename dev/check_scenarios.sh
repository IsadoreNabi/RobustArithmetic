#!/usr/bin/env bash
## Exercise the installed package and its session safeguards in fresh processes.
##
## Usage:
##   bash dev/check_scenarios.sh <source tree> <nonexistent output directory>

set -u
export LC_ALL=C LC_NUMERIC=C

SOURCE_TREE=${1:?source tree}
OUTPUT_DIR=${2:?nonexistent output directory}
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
SCENARIO_DIR="$SCRIPT_DIR/scenarios"
RA_NOLD_R=${RA_NOLD_R:-/home/josemgomezj/.local/opt/R-4.6.1-noLD/bin/R}
NOLD_BIN=$(dirname "$RA_NOLD_R")
NOLD_RSCRIPT="$NOLD_BIN/Rscript"

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
if [ ! -x "$NOLD_RSCRIPT" ]; then
  incomplete "Rscript without long double: $NOLD_RSCRIPT"
fi

mkdir -p "$OUTPUT_DIR/build" "$OUTPUT_DIR/lib_sys" "$OUTPUT_DIR/lib_nold" \
  "$OUTPUT_DIR/empty_user_lib" || fail_setup "cannot create output directories"

if ! Rscript --vanilla -e \
  'quit(status = if (requireNamespace("Rmpfr", quietly = TRUE)) 0L else 1L)'; then
  incomplete "Rmpfr for system R"
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
  local library=$3
  local attach=$4
  local scenario=$5
  local user_library=$6
  local run_suite=$7
  shift 7
  local environment=(-u NOT_CRAN
    "R_LIBS=$library"
    "R_PROFILE_USER=$SCENARIO_DIR/hook_scenario.R"
    "RA_SCENARIO=$scenario"
    "RA_SCENARIO_ATTACH=$attach"
    "RA_SCENARIO_LIBRARY=$library")
  if [ -n "$user_library" ]; then
    environment+=("R_LIBS_USER=$user_library")
  fi

  local suite_code=""
  local summary=""
  local failures=""
  if [ "$run_suite" = yes ]; then
    local run_dir="$OUTPUT_DIR/run_$name"
    mkdir -p "$run_dir" &&
      cp -r "$OUTPUT_DIR/build/RobustArithmetic/tests/." "$run_dir/" ||
      fail_setup "cannot prepare scenario $name"
    (cd "$run_dir" && env "${environment[@]}" "$rscript" testthat.R \
      > testthat.Rout 2>&1)
    suite_code=$?
    summary=$(grep -o '\[ FAIL [0-9]* | WARN [0-9]* | SKIP [0-9]* | PASS [0-9]* \]' \
      "$run_dir/testthat.Rout" | tail -n 1)
    failures=$(grep -E '^(──|--) (Failure|Error) ' "$run_dir/testthat.Rout" |
      sed -E -e 's/^(──|--) //' -e 's/ (─+|-+)$//' | tr '\n' ';')
  fi

  env "${environment[@]}" "$rscript" "$SCENARIO_DIR/probe_scenario.R" \
    > "$OUTPUT_DIR/$name.log" 2>&1
  local probe_code=$?
  local probe
  probe=$(grep '^PROBE' "$OUTPUT_DIR/$name.log" | tail -n 1)
  local verdict=OK
  if [ "$run_suite" = yes ]; then
    [ "$suite_code" -eq 0 ] || verdict=BAD
    [ -n "$summary" ] || verdict=BAD
    printf '%s' "$summary" | grep -q '^\[ FAIL 0 ' || verdict=BAD
  fi
  [ "$probe_code" -eq 0 ] || verdict=BAD
  [ -n "$probe" ] || verdict=BAD
  local wanted
  for wanted in "$@"; do
    if ! printf '%s' "$probe" | grep -q -- " $wanted"; then
      verdict=BAD
      echo "  $name missing: $wanted"
    fi
  done
  ran=$((ran + 1))
  local line="SCENARIO $name"
  if [ "$run_suite" = yes ]; then
    line="$line exit=$suite_code summary=${summary:-NONE}"
  fi
  line="$line probe_exit=$probe_code ${probe:-PROBE NONE} verdict=$verdict"
  echo "$line"
  if [ "$verdict" = BAD ]; then
    bad=$((bad + 1))
    if [ -n "$failures" ]; then
      echo "SCENARIO_FAILURE $name $failures"
    fi
  fi
}

common="exports=60 anchor_exported=FALSE status_exported=TRUE"
run_scenario healthy_sys Rscript "$OUTPUT_DIR/lib_sys" yes healthy "" yes \
  startup=0 degraded=FALSE sentinel_sin_bad=FALSE warnings=0 errors=0 \
  prov=measured rmpfr=TRUE $common
run_scenario loaddeg_sys Rscript "$OUTPUT_DIR/lib_sys" yes loaddeg "" yes \
  startup=1 startup_degraded=TRUE degraded=TRUE reason_sin=TRUE \
  sentinel_sin_bad=TRUE warnings=1 warnings_of_class=1 errors=0 \
  prov=theorem rmpfr=TRUE $common
run_scenario broken_sys Rscript "$OUTPUT_DIR/lib_sys" yes broken "" no \
  startup=1 startup_degraded=TRUE degraded=TRUE reason_sin=TRUE \
  sentinel_sin_bad=TRUE warnings=1 warnings_of_class=1 errors=0 \
  prov=theorem rmpfr=TRUE $common
run_scenario healthy_colon Rscript "$OUTPUT_DIR/lib_sys" no healthy "" no \
  startup=0 degraded=FALSE sentinel_sin_bad=FALSE warnings=0 errors=0 \
  prov=measured rmpfr=TRUE $common
run_scenario broken_colon Rscript "$OUTPUT_DIR/lib_sys" no broken "" no \
  startup=0 degraded=TRUE reason_sin=TRUE sentinel_sin_bad=TRUE \
  warnings=1 warnings_of_class=1 errors=0 prov=theorem rmpfr=TRUE $common
run_scenario healthy_nold_nompfr "$NOLD_RSCRIPT" "$OUTPUT_DIR/lib_nold" \
  yes healthy "$OUTPUT_DIR/empty_user_lib" yes startup=0 degraded=FALSE \
  sentinel_sin_bad=FALSE warnings=0 errors=0 prov=measured rmpfr=FALSE $common
run_scenario loaddeg_nold_nompfr "$NOLD_RSCRIPT" "$OUTPUT_DIR/lib_nold" \
  yes loaddeg "$OUTPUT_DIR/empty_user_lib" yes startup=1 \
  startup_degraded=TRUE degraded=TRUE reason_sin=TRUE \
  sentinel_sin_bad=TRUE warnings=0 errors=16 errors_of_class=16 \
  prov=none rmpfr=FALSE $common
run_scenario broken_nold_nompfr "$NOLD_RSCRIPT" "$OUTPUT_DIR/lib_nold" \
  yes broken "$OUTPUT_DIR/empty_user_lib" no startup=1 startup_degraded=TRUE \
  degraded=TRUE reason_sin=TRUE sentinel_sin_bad=TRUE warnings=0 errors=16 \
  errors_of_class=16 prov=none rmpfr=FALSE $common

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
