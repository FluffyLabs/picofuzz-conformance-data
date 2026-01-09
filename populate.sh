#!/bin/bash
#
cd "$(dirname "${BASH_SOURCE[0]}")"

set -ex

CONVERT="npx @typeberry/convert@0.5.1-a175c9e --"
SOURCE=./jam-conformance/fuzz-reports/0.7.2/traces
DEST=./picofuzz-data
VERSION_FILE=$DEST/version

# Get the current jam-conformance ref
JAM_VECTORS_REF=$(cd ./jam-conformance && git rev-parse HEAD)

# Check if version file exists and matches
if [ -f "$VERSION_FILE" ]; then
  CURRENT_VERSION=$(cat "$VERSION_FILE")
  if [ "$CURRENT_VERSION" = "$JAM_VECTORS_REF" ]; then
    echo "Version matches ($JAM_VECTORS_REF), nothing to do."
    echo "Remove $VERSION_FILE to regenerate the test cases."
    exit 0
  fi
fi

echo "Generating test data from jam-conformance ref: $JAM_VECTORS_REF"

MAX_JOBS=5
counter=0

while IFS= read -r bin_file; do
  file_num_even=$(printf "%08d" $((counter * 2)))
  file_num_odd=$(printf "%08d" $((counter * 2 + 1)))

  $CONVERT $bin_file \
    stf-vector as-state-fuzz-message to-bin \
    $DEST/$DIR/$file_num_even.bin &

  $CONVERT $bin_file \
    stf-vector as-block-fuzz-message to-bin \
    $DEST/$DIR/$file_num_odd.bin &

  if (( (counter + 1) % MAX_JOBS == 0 )); then
    wait
  fi

  ((counter++))
done < <(find "$SOURCE" -type f -name "*.bin" | sort)

wait

# Save the version after successful completion
echo "$JAM_VECTORS_REF" > "$VERSION_FILE"
echo "Successfully generated test data. Version saved to $VERSION_FILE"
