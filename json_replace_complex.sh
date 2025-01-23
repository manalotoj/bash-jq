#!/bin/bash

# Print usage information
usage() {
  echo "Usage: $0 -t <file_or_directory> -f <filter> [-v <new_value>] [-x <prefix>] [-y <suffix>] [-h]"
  echo ""
  echo "Options:"
  echo "  -t <file_or_directory>  Specify the JSON file or directory to process."
  echo "  -f <filter>             Provide a jq filter to identify the field to update."
  echo "  -v <new_value>          New value to replace the identified field (optional)."
  echo "  -x <prefix>             Prefix to add to the identified field (optional)."
  echo "  -y <suffix>             Suffix to add to the identified field (optional)."
  echo "  -h                      Display this help message and exit."
  echo ""
  echo "Examples:"
  echo "  Replace value in a file: $0 -t target/sample.json -f '.name' -v 'new_value'"
  echo "  Add prefix to a field:   $0 -t target/sample.json -f '.name' -x 'prefix_'"
  echo "  Update all JSON files:   $0 -t ./json_files/ -f '.metadata.version' -v '2.0.0'"
  echo "  Update specific array:   $0 -t ./json_files/ -f '.array[] | select(.key == \"value\") | .target_field' -v 'updated_value'"
  exit 0
}

# Function to process and update a JSON file
process_json_file() {
  local file="$1"
  local filter="$2"
  local new_value="$3"
  local prefix="$4"
  local suffix="$5"

  # Construct jq filter
  local jq_filter
  if [[ -n "$prefix" || -n "$suffix" ]]; then
    jq_filter="($filter) |= (\$prefix + . + \$suffix)"
  elif [[ -n "$new_value" ]]; then
    jq_filter="($filter) = \$value"
  else
    echo "Error: Either a new value or prefix/suffix must be specified."
    return 1
  fi

  echo "Debug: Applying jq filter: $jq_filter on file $file"  # Debugging output

  # Create a temporary file for processing
  tmp_file=$(mktemp)
  jq --arg value "$new_value" --arg prefix "$prefix" --arg suffix "$suffix" \
     "$jq_filter" "$file" > "$tmp_file"

  # Check if jq succeeded
  if [[ $? -ne 0 ]]; then
    echo "Error: jq failed on $file. Check your JSON structure and filter."
    rm -f "$tmp_file"
    return 1
  fi

  # Overwrite the original file with the updated content
  mv "$tmp_file" "$file"
  echo "Updated $file successfully."
}

# Function to process all JSON files in a directory recursively
process_directory() {
  local dir="$1"
  local filter="$2"
  local new_value="$3"
  local prefix="$4"
  local suffix="$5"

  find "$dir" -type f -name "*.json" | while read -r json_file; do
    echo "Processing $json_file"
    process_json_file "$json_file" "$filter" "$new_value" "$prefix" "$suffix"
  done
}


# Parse arguments
while getopts ":t:f:v:x:y:h" opt; do
  case $opt in
    t) target="$OPTARG" ;;
    f) filter="$OPTARG" ;;
    v) new_value="$OPTARG" ;;
    x) prefix="$OPTARG" ;;
    y) suffix="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

# Validate arguments
if [[ -z "$target" || -z "$filter" ]]; then
  usage
fi

# Default values for prefix and suffix
prefix="${prefix:-}"
suffix="${suffix:-}"

# Check if target is a file or directory
if [[ -f "$target" ]]; then
  echo "Processing single file: $target"
  process_json_file "$target" "$filter" "$new_value" "$prefix" "$suffix"
elif [[ -d "$target" ]]; then
  echo "Processing directory: $target"
  process_directory "$target" "$filter" "$new_value" "$prefix" "$suffix"
else
  echo "Error: $target is not a valid file or directory."
  exit 1
fi

echo "Processing completed."
