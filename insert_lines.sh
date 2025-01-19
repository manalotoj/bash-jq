#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 <file> <line_number> <'before'|'after'> <text_to_insert>"
    echo "Example: $0 myfile.txt 3 before 'Inserted line 1\nInserted line 2'"
    exit 1
}

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

# Prepare the sed command
if [ "$POSITION" == "before" ]; then
    SED_COMMAND="${LINE_NUMBER}i\\
$TEXT"
else
    SED_COMMAND="${LINE_NUMBER}a\\
$TEXT"
fi

# Apply the sed command to modify the file
sed -i.bak -e "$SED_COMMAND" "$FILE"

echo "Text has been inserted into '$FILE'. A backup has been created as '$FILE.bak'."
