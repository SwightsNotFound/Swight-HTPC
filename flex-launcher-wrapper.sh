#!/bin/bash

cd ~/flex-launcher || exit 1

# Define the log file path using ~ expansion
LOG_FILE=~/.local/share/flex-launcher/flex-launcher.log

# Initialize try counter
try_count=0
max_attempts=10

# Function to clean up processes
cleanup() {
    echo "Cleaning up processes..."
    # Kill flex-launcher and any child processes
    pkill -f "flex-launcher -d" 2>/dev/null
    # Kill any remaining processes from this script
    if [ -n "$LAUNCHER_PID" ] && kill -0 $LAUNCHER_PID 2>/dev/null; then
        kill -TERM $LAUNCHER_PID 2>/dev/null
        sleep 1
        kill -KILL $LAUNCHER_PID 2>/dev/null 2>/dev/null
    fi
}

# Set up trap to ensure cleanup on exit
trap cleanup EXIT INT TERM

echo "Starting flex-launcher monitor..."

while [ $try_count -lt $max_attempts ]; do
    # Increment try counter
    ((try_count++))

    # Ensure log file exists
    touch "$LOG_FILE"

    echo "Try $try_count: Starting flex-launcher..."

    # Run flex-launcher in the background with -d flag
    ./flex-launcher -d &
    LAUNCHER_PID=$!

    # Wait for 2 seconds total (increased from 1)
    sleep 2

    # Check if the process is still running
    if ! kill -0 $LAUNCHER_PID 2>/dev/null; then
        echo "Try $try_count: flex-launcher died immediately, restarting..."
        continue
    fi

    # Check log for success condition
    if grep -q "Video Information" "$LOG_FILE" 2>/dev/null; then
        echo "Success on try $try_count: Video Information found in log!"
        echo "flex-launcher is running with PID: $LAUNCHER_PID"

        # Wait a moment to ensure it's stable
        sleep 2

        # Double check it's still running
        if kill -0 $LAUNCHER_PID 2>/dev/null; then
            echo "flex-launcher running stable. Monitor script exiting."
            # Clear the trap and exit cleanly, leaving flex-launcher running
            trap - EXIT INT TERM
            exit 0
        else
            echo "flex-launcher crashed after initial success, continuing..."
        fi
    fi

    # If we get here, either no Video Information or process died
    echo "Try $try_count: Conditions not met, stopping flex-launcher..."

    # Kill the process group to ensure all children are terminated
    kill -TERM $LAUNCHER_PID 2>/dev/null
    sleep 0.5
    # Force kill if still running
    kill -KILL $LAUNCHER_PID 2>/dev/null 2>/dev/null
    wait $LAUNCHER_PID 2>/dev/null

    # Clear PID variable
    unset LAUNCHER_PID

    # Brief pause before retry
    sleep 1
done

echo "Failed to start flex-launcher after $max_attempts attempts"
echo "Please check flex-launcher manually"
exit 1
