#!/bin/bash

# Function to process and update a JSON file
process_json_file() {
  local file="$1"
  local jsonpath="$2"
  local new_value="$3"
  local prefix="$4"
  local suffix="$5"

  # Determine the jq filter based on provided options
  local jq_filter
  if [[ "$jsonpath" == ..* ]]; then
    # Handle recursive paths with `..`
    jq_filter="walk(if type == \"object\" and has(\"inner\") then .inner |= (if has(\"name\") then .name = \$value else . end) else . end)"
  else
    # Handle normal paths
    if [[ -n "$prefix" || -n "$suffix" ]]; then
      jq_filter="$jsonpath |= (\$prefix + . + \$suffix)"
    elif [[ -n "$new_value" ]]; then
      jq_filter="$jsonpath = \$value"
    else
      echo "Error: Either a new value or prefix/suffix must be specified."
      return 1
    fi
  fi

  echo "Debug: Applying jq filter: $jq_filter"  # Debugging output

  tmp_file=$(mktemp)
  jq --arg value "$new_value" --arg prefix "$prefix" --arg suffix "$suffix" \
     "$jq_filter" "$file" > "$tmp_file"

  # Check if jq succeeded
  if [[ $? -ne 0 ]]; then
    echo "Error: jq failed. Check your JSON structure and filter."
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$file"
  echo "Updated $file successfully."
}

# Function to process files in a directory recursively
process_directory() {
  local dir="$1"
  local jsonpath="$2"
  local new_value="$3"
  local prefix="$4"
  local suffix="$5"

  find "$dir" -type f -name "*.json" | while read -r json_file; do
    echo "Processing $json_file"
    process_json_file "$json_file" "$jsonpath" "$new_value" "$prefix" "$suffix"
  done
}

# Print usage information
usage() {
  echo "Usage: $0 -t <file_or_directory> -p <jsonpath> [-v <new_value>] [-x <prefix>] [-y <suffix>]"
  echo "Examples:"
  echo "  Replace value: $0 -t target/sample.json -p '.name' -v 'new_value'"
  echo "  Add prefix:    $0 -t target/sample.json -p '.name' -x 'prefix_'"
  echo "  Add suffix:    $0 -t target/sample.json -p '.name' -y '_suffix'"
  echo "  Recursive:     $0 -t target/sample.json -p '..inner.name' -v 'new'"
  exit 1
}

# Parse arguments
while getopts ":t:p:v:x:y:" opt; do
  case $opt in
    t) target="$OPTARG" ;;
    p) jsonpath="$OPTARG" ;;
    v) new_value="$OPTARG" ;;
    x) prefix="$OPTARG" ;;
    y) suffix="$OPTARG" ;;
    *) usage ;;
  esac
done

# Validate arguments
if [[ -z "$target" || -z "$jsonpath" ]]; then
  usage
fi

# Default values for prefix and suffix
prefix="${prefix:-}"
suffix="${suffix:-}"

# Check if target is a file or directory
if [[ -f "$target" ]]; then
  echo "Processing single file: $target"
  process_json_file "$target" "$jsonpath" "$new_value" "$prefix" "$suffix"
elif [[ -d "$target" ]]; then
  echo "Processing directory: $target"
  process_directory "$target" "$jsonpath" "$new_value" "$prefix" "$suffix"
else
  echo "Error: $target is not a valid file or directory."
  exit 1
fi

echo "Processing completed."
