#!/usr/bin/env bash
# =============================================================================
# PURSUE visual-evidence — one-command reproduction / falsification harness
# -----------------------------------------------------------------------------
# What it does (in order):
#   1. RE-DOWNLOADS the 14 image files + uap-data.csv from war.gov by DEFAULT.
#      Only if war.gov's WAF (Akamai) blocks an automated fetch does it fall
#      back to the bundled copy for THAT file — and it says so, loudly.
#   2. Hash-verifies every acquired file against manifest.sha256.
#   3. Re-runs exiftool -a -G1 -s -json and diffs against the bundled dump
#      (SourceFile paths normalized away).
#   4. Runs the marker DETECTOR on the 14 files AND on controls/ .
#      The controls prove the detector is live: positive => every marker fires,
#      neutral => none. That is what turns "0 genai / 0 C2PA" into a finding
#      instead of a silent tool failure.
#   5. Prints a PASS/FAIL summary.
#
# Usage:
#   ./reproduce.sh                 # full: re-download from war.gov, verify, re-derive
#   ./reproduce.sh --no-download   # offline: verify the bundled copies only
#
# Requirements: bash, curl, (shasum|sha256sum), exiftool, and optionally jq.
# Designed to run on stock macOS (bash 3.2) and Linux. No network is required
# in --no-download mode.
# =============================================================================
set -u
cd "$(dirname "$0")"
ROOT="$(pwd)"
MODE="${1:-}"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"

sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'; else sha256sum "$1" | awk '{print $1}'; fi; }
have() { command -v "$1" >/dev/null 2>&1; }
is_jpeg() { [ -s "$1" ] && [ "$(head -c2 "$1" | od -An -tx1 | tr -d ' \n')" = "ffd8" ]; }

have exiftool || echo "WARN: exiftool not found -> step 3 (metadata re-derivation) will be skipped."
have jq || echo "WARN: jq not found -> exiftool diff will be textual, not structural."

WORK="$ROOT/_repro"; rm -rf "$WORK"; mkdir -p "$WORK/dl"
PASS=0; FAIL=0
ok(){ echo "  PASS  $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL  $1"; FAIL=$((FAIL+1)); }

# ---- read manifest.sha256 as the single source of truth (url + hash + path) ----
# emits: <relpath>\t<expected_sha>\t<url>
MAN="$WORK/manifest.tsv"; : > "$MAN"
url=""
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    "# http"*) url="${line#\# }";;
    "#"*|"") : ;;
    *) h="$(printf '%s' "$line" | awk '{print $1}')"
       p="$(printf '%s' "$line" | awk '{print $2}')"
       [ -n "$h" ] && printf '%s\t%s\t%s\n' "$p" "$h" "$url" >> "$MAN"; url="";;
  esac
done < manifest.sha256

echo "=============================================================="
echo "STEP 1 — acquire files (default: re-download from war.gov)"
echo "=============================================================="
fellback=0
while IFS="$(printf '\t')" read -r rel exp url; do
  out="$WORK/dl/$(basename "$rel")"
  src="war.gov"
  if [ "$MODE" = "--no-download" ] || [ -z "$url" ]; then
    cp "$rel" "$out"; src="bundled (mode=$MODE)"
  else
    if curl -fsSL -A "$UA" --max-time 90 "$url" -o "$out" 2>/dev/null && { is_jpeg "$out" || case "$rel" in *.csv) [ -s "$out" ];; *) false;; esac; }; then
      src="war.gov (live)"
    else
      cp "$rel" "$out"; src="BUNDLED-FALLBACK (war.gov blocked)"; fellback=$((fellback+1))
    fi
  fi
  printf "  %-22s <- %s\n" "$(basename "$rel")" "$src"
done < "$MAN"
[ "$fellback" -gt 0 ] && echo "  NOTE: $fellback file(s) fell back to bundled copies (Akamai/WAF block is expected for automated fetches; a human using a browser session can re-fetch and hash-compare manually)."

echo
echo "=============================================================="
echo "STEP 2 — SHA-256 verify (acquired vs manifest)"
echo "=============================================================="
hbad=0
while IFS="$(printf '\t')" read -r rel exp url; do
  got="$(sha "$WORK/dl/$(basename "$rel")")"
  if [ "$got" = "$exp" ]; then
    printf "  OK    %-22s %s\n" "$(basename "$rel")" "$got"
  else
    # CSV may differ only by BOM/CRLF -> normalized compare
    if case "$rel" in *.csv) true;; *) false;; esac; then
      na="$WORK/dl/csv.norm"; nb="$WORK/csv.bundled.norm"
      sed '1s/^\xEF\xBB\xBF//' "$WORK/dl/$(basename "$rel")" | tr -d '\r' > "$na"
      sed '1s/^\xEF\xBB\xBF//' "$rel" | tr -d '\r' > "$nb"
      if [ "$(sha "$na")" = "$(sha "$nb")" ]; then
        printf "  OK*   %-22s content-identical modulo BOM/CRLF (raw got=%s)\n" "$(basename "$rel")" "$got"
      else
        printf "  DIFF  %-22s got=%s exp=%s\n" "$(basename "$rel")" "$got" "$exp"; hbad=$((hbad+1))
      fi
    else
      printf "  DIFF  %-22s got=%s exp=%s\n" "$(basename "$rel")" "$got" "$exp"; hbad=$((hbad+1))
    fi
  fi
done < "$MAN"
[ "$hbad" -eq 0 ] && ok "hash-verify: all files match manifest (modulo documented CSV BOM/CRLF)" || no "hash-verify: $hbad file(s) mismatched"

echo
echo "=============================================================="
echo "STEP 3 — re-derive exiftool metadata and diff vs bundled dump"
echo "=============================================================="
if have exiftool; then
  ORDER="NASA-UAP-VM001 NASA-UAP-VM002 NASA-UAP-VM003 NASA-UAP-VM004 NASA-UAP-VM005 NASA-UAP-VM006 FBI-UAP-D016 FBI-UAP-D017 FBI-UAP-D018 FBI-UAP-D019 FBI-UAP-D020 FBI-UAP-D021 FBI-UAP-D022 FBI-UAP-D023"
  args=""; for n in $ORDER; do args="$args $WORK/dl/$n.jpg"; done
  exiftool -a -G1 -s -json $args > "$WORK/repro.json" 2>/dev/null
  if have jq; then
    NORM='map(with_entries(select(.key|startswith("System:")|not)) | del(.SourceFile))'
    jq "$NORM" "$WORK/repro.json" > "$WORK/repro.norm.json"
    jq "$NORM" exiftool-dump.json > "$WORK/bundled.norm.json"
    if diff -q "$WORK/bundled.norm.json" "$WORK/repro.norm.json" >/dev/null; then
      ok "exiftool re-derivation identical to bundled dump (content fields)"
    else
      no "exiftool re-derivation differs from bundled dump — inspect: diff bundled.norm.json repro.norm.json"
      diff "$WORK/bundled.norm.json" "$WORK/repro.norm.json" | head -20
    fi
  else
    echo "  (jq missing) re-derived dump written to _repro/repro.json; compare manually to exiftool-dump.json"
  fi
else
  echo "  SKIPPED (exiftool not installed)"
fi

echo
echo "=============================================================="
echo "STEP 4 — MARKER DETECTOR (the AI-labelling question)"
echo "=============================================================="
# Detector = case-insensitive raw-byte grep for each marker family.
cnt(){ grep -aoiE "$2" "$1" 2>/dev/null | wc -l | tr -d ' '; }
scanline(){ # $1 file  $2 label
  f="$1"; lbl="$2"
  acct=$(cnt "$f" 'OneDrive - DoD365'); gvn=$(cnt "$f" 'genai'); c2=$(cnt "$f" 'c2pa|jumbf|content.?credential')
  gen=$(cnt "$f" 'generated'); autg=$(cnt "$f" 'autoGenerated'); art=$(cnt "$f" 'artificial|synthetic')
  adobe=$(cnt "$f" 'Adobe (Photoshop|Illustrator)')
  scn=$(cnt "$f" 'Witness_[0-9]+-UAPs-SCENE')   # raw bytes (XMP/text)
  if command -v exiftool >/dev/null 2>&1; then   # Photoshop slice names are UTF-16 in the IRB -> read via exiftool
    e=$(exiftool -s3 -Photoshop:SlicesGroupName "$f" 2>/dev/null | grep -ciE 'Witness_[0-9]+-UAPs-SCENE'); scn=$((scn+e))
  fi
  genx=$((gen-autg))   # "generated" occurrences that are NOT the benign autoGenerated slice attribute
  printf "  %-20s acct=%s genai=%s c2pa=%s artif/syn=%s | gen=%s(auto=%s,other=%s) adobe=%s scene=%s\n" \
    "$lbl" "$acct" "$gvn" "$c2" "$art" "$gen" "$autg" "$genx" "$adobe" "$scn"
  echo "$gvn $c2 $art $genx $acct" >> "$WORK/agg.$3"
}
: > "$WORK/agg.nasa"; : > "$WORK/agg.fbi"
echo "-- 6 NASA composites --"
for n in NASA-UAP-VM001 NASA-UAP-VM002 NASA-UAP-VM003 NASA-UAP-VM004 NASA-UAP-VM005 NASA-UAP-VM006; do scanline "$WORK/dl/$n.jpg" "$n" nasa; done
echo "-- 8 FBI 'orb' renders --"
for n in FBI-UAP-D016 FBI-UAP-D017 FBI-UAP-D018 FBI-UAP-D019 FBI-UAP-D020 FBI-UAP-D021 FBI-UAP-D022 FBI-UAP-D023; do scanline "$WORK/dl/$n.jpg" "$n" fbi; done
echo "-- CONTROLS --"
: > "$WORK/agg.ctl"
scanline "controls/positive_control.jpg" "positive_control" ctl
scanline "controls/neutral_control.jpg" "neutral_control" ctl

# aggregate assertions
sumcol(){ awk -v c="$1" '{s+=$c} END{print s+0}' "$2"; }
ai_total=$(( $(sumcol 1 "$WORK/agg.nasa") + $(sumcol 1 "$WORK/agg.fbi") + $(sumcol 2 "$WORK/agg.nasa") + $(sumcol 2 "$WORK/agg.fbi") + $(sumcol 3 "$WORK/agg.nasa") + $(sumcol 3 "$WORK/agg.fbi") ))
genother=$(( $(sumcol 4 "$WORK/agg.nasa") + $(sumcol 4 "$WORK/agg.fbi") ))
acct_nasa=$(sumcol 5 "$WORK/agg.nasa"); acct_fbi=$(sumcol 5 "$WORK/agg.fbi")
pos_all=$(head -1 "$WORK/agg.ctl"); neu_all=$(tail -1 "$WORK/agg.ctl")

echo
[ "$ai_total" -eq 0 ] && ok "AI-marker scan: 0 genai + 0 C2PA + 0 artificial/synthetic across all 14 files" \
                       || no "AI-marker scan: found $ai_total AI-family marker(s) across the 14 files (INVESTIGATE)"
[ "$genother" -eq 0 ] && ok "'generated' disclosure: every 'generated' occurrence is the benign Adobe 'autoGenerated' slice attribute (non-AI); other='0'" \
                       || no "'generated' disclosure: $genother 'generated' token(s) are NOT autoGenerated (INVESTIGATE)"
[ "$acct_nasa" -eq 6 ] && ok "account-path detector: fires on 6/6 NASA composites (HalterJL1 / DoD365-Joint)" \
                        || no "account-path detector: fired on $acct_nasa/6 NASA composites (expected 6)"
[ "$acct_fbi" -eq 0 ]  && ok "account-path detector: 0/8 FBI files carry a user account path (systematic absence)" \
                        || no "account-path detector: fired on $acct_fbi/8 FBI files (expected 0)"
# controls: positive must fire at least on genai+c2pa+acct (cols1,2,5); neutral must be all-zero
posfire=$(awk 'NR==1{print ($1>0 && $2>0 && $5>0)?1:0}' "$WORK/agg.ctl")
neufire=$(awk 'NR==2{print $1+$2+$3+$4+$5}' "$WORK/agg.ctl")
[ "$posfire" = "1" ] && ok "control POSITIVE: detector fires (genai>0, c2pa>0, account-path>0)" || no "control POSITIVE did not fire — detector may be broken"
[ "$neufire" -eq 0 ] && ok "control NEUTRAL: detector silent (0 markers)" || no "control NEUTRAL tripped $neufire marker(s) — false-positive risk"

echo
echo "=============================================================="
echo "RESULT:  PASS=$PASS  FAIL=$FAIL"
echo "=============================================================="
echo "Interpretation: PASS on every line means an independent party, re-downloading"
echo "from war.gov, reproduces (a) the exact bytes, (b) the Adobe montage metadata,"
echo "and (c) the absence of any AI-generation marker — with a live detector proven"
echo "by the controls. It does NOT prove who authored the FBI chain, nor the craft"
echo "origin of anything. See README.md."
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
