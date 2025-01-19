#!/bin/bash

# Function to process and update a JSON file
process_json_file() {
  local file="$1"
  local prefix="$2"
  local suffix="$3"

  # Use jq to add prefix/suffix to all "name" fields
  tmp_file=$(mktemp)
  jq --arg prefix "$prefix" --arg suffix "$suffix" '
    walk(if type == "object" and has("name") then .name = $prefix + .name + $suffix else . end)
  ' "$file" > "$tmp_file" && mv "$tmp_file" "$file" || {
    echo "Error: Failed to update JSON in file '$file'."
    rm -f "$tmp_file"
  }
}

# Function to process files in a directory recursively
process_directory() {
  local dir="$1"
  local prefix="$2"
  local suffix="$3"

  find "$dir" -type f -name "*.json" | while read -r json_file; do
    echo "Processing $json_file"
    process_json_file "$json_file" "$prefix" "$suffix"
  done
}

# Print usage information
usage() {
  echo "Usage: $0 -t <file_or_directory> [-x <prefix>] [-y <suffix>]"
  echo "Examples:"
  echo "  Add prefix: $0 -t target/sample.json -x 'prefix_'"
  echo "  Add suffix: $0 -t target/sample.json -y '_suffix'"
  echo "  Add both:   $0 -t target/sample.json -x 'prefix_' -y '_suffix'"
  exit 1
}

# Parse arguments
while getopts ":t:x:y:" opt; do
  case $opt in
    t) target="$OPTARG" ;;
    x) prefix="$OPTARG" ;;
    y) suffix="$OPTARG" ;;
    *) usage ;;
  esac
done

# Validate arguments
if [[ -z "$target" ]]; then
  usage
fi

# Default values for prefix and suffix
prefix="${prefix:-}"
suffix="${suffix:-}"

# Check if target is a file or directory
if [[ -f "$target" ]]; then
  echo "Processing single file: $target"
  process_json_file "$target" "$prefix" "$suffix"
elif [[ -d "$target" ]]; then
  echo "Processing directory: $target"
  process_directory "$target" "$prefix" "$suffix"
else
  echo "Error: $target is not a valid file or directory."
  exit 1
fi

echo "Processing completed."
