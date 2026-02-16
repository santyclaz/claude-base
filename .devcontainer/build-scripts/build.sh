#!/bin/bash

echo "Checking for build scripts to run..."

IFS=' ' read -r -a scripts <<< "$BUILD_SCRIPTS"
scripts_count=${#scripts[@]}

success_count=0
error_count=0

# Loop through the list
for script in "${scripts[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        echo "Running: $script"
        # Execute the script
        ./"$script"
        ((success_count++))
    elif [ -f "$script.sh" ] && [ -x "$script.sh" ]; then
        echo "Running: $script.sh"
        # Execute the script
        ./"$script.sh"
        ((success_count++))
    else
        echo "Error: $script not found or not executable"
        ((error_count++))
    fi
done

if [ "$scripts_count" -eq 0 ]; then
    echo "No build scripts to run"
else
    echo "Done running build scripts (success: $success_count, error: $error_count, total: $scripts_count)"
fi
