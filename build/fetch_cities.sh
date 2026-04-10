#!/bin/bash
# Fetch & prep the GeoNames cities5000 dataset with admin1 (state/province)
# names and coordinates resolved, written to MenuClock/Resources/cities.tsv.
# Data © GeoNames (https://www.geonames.org), licensed under CC BY 4.0.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="MenuClock/Resources/cities.tsv"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "→ Downloading cities5000 from GeoNames…"
curl -fsSL -o "$TMP/cities5000.zip" https://download.geonames.org/export/dump/cities5000.zip

echo "→ Downloading admin1CodesASCII.txt…"
curl -fsSL -o "$TMP/admin1CodesASCII.txt" https://download.geonames.org/export/dump/admin1CodesASCII.txt

echo "→ Extracting…"
unzip -q -o "$TMP/cities5000.zip" -d "$TMP"

# admin1CodesASCII.txt columns: 1 code (CC.XX), 2 name, 3 ascii name, 4 geonameid
# cities5000.txt   columns:     1 geonameid, 2 name, 3 asciiname, 4 alt, 5 lat,
#                               6 lng, 7 feature_class, 8 feature_code, 9 country,
#                               10 cc2, 11 admin1, 12 admin2..14 admin4, 15 pop,
#                               16 elevation, 17 dem, 18 timezone, 19 moddate
#
# Output columns (tab-separated):
#   1 name           (display, may contain accents)
#   2 asciiname      (for search)
#   3 country code   (ISO alpha-2)
#   4 admin1 name    (resolved state/province/region; may be empty)
#   5 population     (integer)
#   6 timezone       (IANA)
#   7 latitude       (float)
#   8 longitude      (float)
echo "→ Joining admin1 names and projecting columns…"
awk -F'\t' 'BEGIN{OFS="\t"}
  NR==FNR { a1[$1] = $2; next }
  {
    key = $9 "." $11
    admin = (key in a1) ? a1[key] : ""
    print $2, $3, $9, admin, $15, $18, $5, $6
  }
' "$TMP/admin1CodesASCII.txt" "$TMP/cities5000.txt" > "$TMP/joined.tsv"

echo "→ Sorting by population (descending)…"
sort -t$'\t' -k5,5 -nr "$TMP/joined.tsv" > "$OUT"

LINES=$(wc -l < "$OUT" | tr -d ' ')
SIZE=$(du -h "$OUT" | cut -f1)
echo "✓ Wrote $OUT ($LINES cities, $SIZE)"
echo
echo "Data © GeoNames — https://www.geonames.org — CC BY 4.0"
