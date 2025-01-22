#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 <file> <line_number> <'before'|'after'> <text_to_insert>"
    echo ""
    echo "Description:"
    echo "  This script inserts the specified text into a file at a given line number."
    echo "  You can specify whether to insert the text 'before' or 'after' the line."
    echo ""
    echo "Arguments:"
    echo "  <file>             The file in which the text should be inserted."
    echo "  <line_number>      The line number where the text should be inserted."
    echo "  <'before'|'after'> Specify whether the text should be inserted 'before' or 'after' the given line number."
    echo "  <text_to_insert>   The text to insert. Use '\\n' to indicate line breaks."
    echo ""
    echo "Example:"
    echo "  $0 myfile.txt 3 before 'Inserted line 1\\nInserted line 2'"
    echo "  Inserts 'Inserted line 1' and 'Inserted line 2' before line 3 of myfile.txt."
    echo ""
    echo "Notes:"
    echo "  - The script creates a backup of the original file with a .bak extension."
    echo "  - Ensure the file exists and is writable before running the script."
    echo "  - The <line_number> must be an integer."
    echo "  - Valid values for <'before'|'after'> are 'before' or 'after'."
    exit 1
}

# Validate arguments
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    usage
fi

# Validate arguments
if [ "$#" -lt 4 ]; then
    usage
fi

FILE="$1"
LINE_NUMBER="$2"
POSITION="$3"
TEXT="$4"

# Check if the file exists
if [ ! -f "$FILE" ]; then
    echo "Error: File '$FILE' does not exist."
    exit 1
fi

# Check if line number is valid
if ! [[ "$LINE_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: Line number must be an integer."
    exit 1
fi

# Check if position is valid
if [[ "$POSITION" != "before" && "$POSITION" != "after" ]]; then
    echo "Error: Position must be 'before' or 'after'."
    exit 1
fi

# Replace escape sequences with actual newlines and carriage returns
TEXT=$(echo -e "$TEXT")

# Prepare the sed command
if [ "$POSITION" == "before" ]; then
    SED_COMMAND="${LINE_NUMBER}i\\
$TEXT"
else
    SED_COMMAND="${LINE_NUMBER}a\\
$TEXT"
fi

# Apply the sed command to modify the file
sed -i -e "$SED_COMMAND" "$FILE"

echo "Text has been inserted into '$FILE'. A backup has been created as '$FILE.bak'."
