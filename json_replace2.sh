#!/bin/bash

# Function to process and update a JSON file
process_json_file() {
  local file="$1"
  local jq_filter="$2"
  local new_value="$3"
  local prefix="$4"
  local suffix="$5"

  # Determine the jq operation based on options
  local jq_operation
  if [[ -n "$prefix" || -n "$suffix" ]]; then
    # Add prefix and/or suffix
    jq_operation="($jq_filter) |= (tostring | \$prefix + . + \$suffix)"
  elif [[ -n "$new_value" ]]; then
    # Replace with new value or transformed value
    jq_operation="($jq_filter) |= (tostring | \$value | gsub(\"{original}\"; .))"
  else
    echo "Error: Either a new value or prefix/suffix must be specified."
    return 1
  fi

  # Validate the JSON file and jq filter
  if ! jq empty "$file" 2>/dev/null; then
    echo "Error: Invalid JSON format in file '$file'."
    return 1
  fi

  # Process the file using jq
  tmp_file=$(mktemp)
  if ! jq --arg value "$new_value" --arg prefix "$prefix" --arg suffix "$suffix" \
     "$jq_operation" "$file" > "$tmp_file"; then
    echo "Error: Invalid jq filter or no matching data in file '$file'."
    rm -f "$tmp_file"
    return 1
  fi

  # Ensure the output is not empty before overwriting the original file
  if [[ ! -s $tmp_file ]]; then
    echo "Error: jq produced empty output. File not modified."
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$file"
}

# Function to process files in a directory recursively
process_directory() {
  local dir="$1"
  local jq_filter="$2"
  local new_value="$3"
  local prefix="$4"
  local suffix="$5"

  find "$dir" -type f -name "*.json" | while read -r json_file; do
    echo "Processing $json_file"
    process_json_file "$json_file" "$jq_filter" "$new_value" "$prefix" "$suffix"
  done
}

# Print usage information
usage() {
  echo "Usage: $0 -t <file_or_directory> -p <jq_filter> [-v <new_value>] [-x <prefix>] [-y <suffix>]"
  echo "Examples:"
  echo "  Replace value: $0 -t target/sample.json -p '.. | .allOf?[]? | select(.field? == \"some_value\").equals' -v 'new_value'"
  echo "  Add prefix:    $0 -t target/sample.json -p '.. | .allOf?[]? | select(.field? == \"some_value\").equals' -x 'prefix_'"
  echo "  Add suffix:    $0 -t target/sample.json -p '.. | .allOf?[]? | select(.field? == \"some_value\").equals' -y '_suffix'"
  echo "  Transform:     $0 -t target/sample.json -p '.. | .allOf?[]? | select(.field? == \"some_value\").equals' -v 'IBM~{original}'"
  echo "Notes:"
  echo "  - For transformations, {original} will be replaced with the current value of the field."
  echo "  - Ensure the jq_filter is valid for jq syntax."
  exit 1
}

# Parse arguments
while getopts ":t:p:v:x:y:" opt; do
  case $opt in
    t) target="$OPTARG" ;;
    p) jq_filter="$OPTARG" ;;
    v) new_value="$OPTARG" ;;
    x) prefix="$OPTARG" ;;
    y) suffix="$OPTARG" ;;
    *) usage ;;
  esac
done

# Validate arguments
if [[ -z "$target" || -z "$jq_filter" ]]; then
  usage
fi

# Default values for prefix and suffix
prefix="${prefix:-}"
suffix="${suffix:-}"

# Check if target is a file or directory
if [[ -f "$target" ]]; then
  echo "Processing single file: $target"
  process_json_file "$target" "$jq_filter" "$new_value" "$prefix" "$suffix"
elif [[ -d "$target" ]]; then
  echo "Processing directory: $target"
  process_directory "$target" "$jq_filter" "$new_value" "$prefix" "$suffix"
else
  echo "Error: $target is not a valid file or directory."
  exit 1
fi

echo "Processing completed."
