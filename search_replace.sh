#!/bin/bash

# Function to display usage instructions
usage() {
    echo "Usage: $0 -s <search_text> -r <replace_text> [-f <file_path>] [-d <directory_path>]"
    echo
    echo "Options:"
    echo "  -s    Text to search for"
    echo "  -r    Text to replace with"
    echo "  -f    Target a specific file"
    echo "  -d    Target a directory (recursively processes all files)"
    echo
    echo "Note: Either -f or -d must be provided, but not both."
    exit 1
}

# Detect the platform (macOS, Linux, Git Bash)
detect_platform() {
    uname_out="$(uname -s)"
    case "${uname_out}" in
        Linux*)     platform="linux";;
        Darwin*)    platform="mac";;
        CYGWIN*|MINGW*|MSYS*) platform="gitbash";;
        *)          platform="unknown";;
    esac
}

# Parse input arguments
while getopts "s:r:f:d:" opt; do
    case $opt in
        s) search_text=$OPTARG ;;
        r) replace_text=$OPTARG ;;
        f) file_path=$OPTARG ;;
        d) dir_path=$OPTARG ;;
        *) usage ;;
    esac
done

# Ensure required arguments are provided
if [[ -z "$search_text" || -z "$replace_text" || ( -z "$file_path" && -z "$dir_path" ) || ( -n "$file_path" && -n "$dir_path" ) ]]; then
    usage
fi

# Function to process a single file
process_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        case "$platform" in
            mac)
                sed -i '' "s/${search_text}/${replace_text}/g" "$file" ;; # macOS `sed` requires an empty '' after -i
            linux|gitbash)
                sed -i "s/${search_text}/${replace_text}/g" "$file" ;;   # Linux/Git Bash `sed` works as-is
            *)
                echo "Unsupported platform: $platform"
                exit 1 ;;
        esac
        echo "Processed file: $file"
    else
        echo "Skipping non-file: $file"
    fi
}

# Detect platform
detect_platform

# Process a single file
if [[ -n "$file_path" ]]; then
    if [[ -f "$file_path" ]]; then
        process_file "$file_path"
    else
        echo "Error: File not found: $file_path"
        exit 1
    fi
fi

# Process files in a directory
if [[ -n "$dir_path" ]]; then
    if [[ -d "$dir_path" ]]; then
        export search_text replace_text platform
        export -f process_file
        find "$dir_path" -type f -exec bash -c 'process_file "$1"' _ {} \;
    else
        echo "Error: Directory not found: $dir_path"
        exit 1
    fi
fi
