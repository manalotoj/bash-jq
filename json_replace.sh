#!/bin/bash

# Function to check if jq is installed
check_jq_installed() {
  if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed or not in your PATH."
    echo "Install 'jq' by following the instructions for your platform:"
    echo "- Windows: Download jq from https://stedolan.github.io/jq/download/"
    echo "- macOS: Use 'brew install jq' (if Homebrew is installed)"
    echo "- Linux: Use your package manager (e.g., 'apt install jq' or 'yum install jq')"
    exit 1
  fi
}

process_json_file() {
  local file="$1"
  local jsonpath="$2"
  local new_value="$3"
  local prefix="$4"
  local suffix="$5"

  # Validate JSON structure
  echo "Debug: Validating JSON structure of file: $file"
  jq . "$file" > /dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    echo "Error: Invalid JSON in file '$file'. Please fix the JSON structure."
    return 1
  fi

  # Construct jq filter dynamically
  local jq_filter
  if [[ "$jsonpath" == ..* ]]; then
    # Recursive path: Use walk to traverse all objects
    local field="${jsonpath#..}"  # Remove leading '..'
    if [[ "$field" == *.* ]]; then
      # Handle nested fields (e.g., ..parent.child)
      local parent="${field%.*}"  # Extract parent (e.g., parent)
      local child="${field#*.}"  # Extract child (e.g., child)
      if [[ -n "$prefix" || -n "$suffix" ]]; then
        jq_filter="walk(if type == \"object\" and has(\"$parent\") and (.[\"$parent\"] | has(\"$child\")) then .[\"$parent\"][\"$child\"] |= (\$prefix + . + \$suffix) else . end)"
      elif [[ -n "$new_value" ]]; then
        jq_filter="walk(if type == \"object\" and has(\"$parent\") and (.[\"$parent\"] | has(\"$child\")) then .[\"$parent\"][\"$child\"] = \$value else . end)"
      fi
    else
      # Handle single fields (e.g., ..field)
      if [[ -n "$prefix" || -n "$suffix" ]]; then
        jq_filter="walk(if type == \"object\" and has(\"$field\") then .[\"$field\"] |= (\$prefix + . + \$suffix) else . end)"
      elif [[ -n "$new_value" ]]; then
        jq_filter="walk(if type == \"object\" and has(\"$field\") then .[\"$field\"] = \$value else . end)"
      fi
    fi
  else
    # Direct path: Update only the specified path
    if [[ "$jsonpath" == *.* ]]; then
      # Handle nested fields (e.g., parent.child)
      local parent="${jsonpath%.*}"  # Extract parent
      local child="${jsonpath#*.}"  # Extract child
      if [[ -n "$prefix" || -n "$suffix" ]]; then
        jq_filter="if has(\"$parent\") and (.[\"$parent\"] | has(\"$child\")) then .[\"$parent\"][\"$child\"] |= (\$prefix + . + \$suffix) else . end"
      elif [[ -n "$new_value" ]]; then
        jq_filter="if has(\"$parent\") and (.[\"$parent\"] | has(\"$child\")) then .[\"$parent\"][\"$child\"] = \$value else . end"
      fi
    else
      # Handle single fields (e.g., .field)
      if [[ -n "$prefix" || -n "$suffix" ]]; then
        jq_filter=".[\"$jsonpath\"] |= (\$prefix + . + \$suffix)"
      elif [[ -n "$new_value" ]]; then
        jq_filter=".[\"$jsonpath\"] = \$value"
      fi
    fi
  fi

  if [[ -z "$jq_filter" ]]; then
    echo "Error: Failed to construct jq filter. Check inputs."
    return 1
  fi

  echo "Debug: Applying jq filter: $jq_filter"

  # Create a temporary file
  local tmp_file
  tmp_file=$(mktemp)

  # Execute jq with the dynamically constructed filter
  echo "Debug: Running jq command:"
  echo "jq --arg value \"$new_value\" --arg prefix \"$prefix\" --arg suffix \"$suffix\" \"$jq_filter\" \"$file\""

  jq --arg value "$new_value" --arg prefix "$prefix" --arg suffix "$suffix" \
     "$jq_filter" "$file" > "$tmp_file" 2> jq_error.log

  # Handle jq errors
  if [[ $? -ne 0 ]]; then
    echo "Error: jq failed with the following error:"
    cat jq_error.log
    rm -f "$tmp_file" jq_error.log
    return 1
  fi

  # Overwrite the original file with the updated content
  mv "$tmp_file" "$file"
  rm -f jq_error.log
  echo "Updated $file successfully."
}

# Function to normalize paths for cross-platform compatibility
normalize_path() {
  local input_path="$1"
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Convert Windows paths for Git Bash compatibility
    echo "$(cygpath -u "$input_path")"
  else
    # Return Unix-like paths as-is
    echo "$input_path"
  fi
}

# Function to process and update a JSON file


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
  echo "  Replace value: $0 -t docs/sample.json -p '.name' -v 'new_value'"
  echo "  Add prefix:    $0 -t docs/sample.json -p '.name' -x 'prefix_'"
  echo "  Add suffix:    $0 -t docs/sample.json -p '.name' -y '_suffix'"
  echo "  Recursive:     $0 -t docs/sample.json -p '..inner.name' -v 'new'"
  echo "  Recursive with prefix/suffix: $0 -t docs/sample.json -p '..inner.name' -x 'prefix_' -y '_suffix'"
  exit 1
}

# Parse arguments
while getopts ":t:p:v:x:y:" opt; do
  case $opt in
    t) target_raw="$OPTARG" ;;
    p) jsonpath="$OPTARG" ;;
    v) new_value="$OPTARG" ;;
    x) prefix="$OPTARG" ;;
    y) suffix="$OPTARG" ;;
    *) usage ;;
  esac
done

# Validate arguments
if [[ -z "$target_raw" || -z "$jsonpath" ]]; then
  usage
fi

# Normalize the target path
target=$(normalize_path "$target_raw")

# Default values for prefix and suffix
prefix="${prefix:-}"
suffix="${suffix:-}"

# Ensure jq is installed
check_jq_installed

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
