#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONTAINER_NAME="physical_ai_server"

# Datasets, HF cache, and trained models are stored on an external drive.
# Ubuntu may append 1, 2, ... to the mount name after reconnecting it.
EXTERNAL_DRIVE_MOUNT="${EXTERNAL_DRIVE_MOUNT:-}"

find_external_drive() {
    local candidate

    if [ -n "$EXTERNAL_DRIVE_MOUNT" ] && mountpoint -q "$EXTERNAL_DRIVE_MOUNT"; then
        return 0
    fi

    for candidate in /media/soju/외장하드*; do
        if mountpoint -q "$candidate" \
            && [ -d "$candidate/physical_ai/datasets" ] \
            && [ -d "$candidate/physical_ai/cache" ] \
            && [ -d "$candidate/physical_ai/models" ]; then
            EXTERNAL_DRIVE_MOUNT="$candidate"
            export EXTERNAL_DRIVE_MOUNT
            return 0
        fi
    done

    return 1
}

# Function to verify the external drive is connected before starting
check_external_drive() {
    if ! find_external_drive; then
        echo "Error: External drive containing physical_ai data is not connected under /media/soju/."
        echo "Datasets, HF cache, and trained models are stored on it - connect it and try again."
        exit 1
    fi

    echo "Using external drive: ${EXTERNAL_DRIVE_MOUNT}"
}

# Function to display help
show_help() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  help                    Show this help message"
    echo "  start                   Start the container"
    echo "  enter                   Enter the running container"
    echo "  stop                    Stop the container"
    echo ""
    echo "Examples:"
    echo "  $0 start                Start container"
    echo "  $0 enter                Enter the running container"
    echo "  $0 stop                 Stop the container"
}

# Function to start the container
start_container() {
    check_external_drive

    # Set up X11 forwarding only if DISPLAY is set
    if [ -n "$DISPLAY" ]; then
        echo "Setting up X11 forwarding..."
        xhost +local:docker || true
    else
        echo "Warning: DISPLAY environment variable is not set. X11 forwarding will not be available."
    fi

    echo "Starting physical_ai_server container..."

    ### rmw_zenoh notice (remove later)
    print_rmw_zenoh_notice
    ### rmw_zenoh notice (remove later)

    # Pull the latest images (physical_ai_server is built locally, not pulled,
    # to avoid clobbering the local build with the Docker Hub image of the same tag)
    docker compose -f "${SCRIPT_DIR}/docker-compose.yml" pull physical_ai_manager

    # Run docker-compose
    docker compose -f "${SCRIPT_DIR}/docker-compose.yml" up -d
}

# Function to enter the container
enter_container() {
    # Set up X11 forwarding only if DISPLAY is set
    if [ -n "$DISPLAY" ]; then
        echo "Setting up X11 forwarding..."
        xhost +local:docker || true
    else
        echo "Warning: DISPLAY environment variable is not set. X11 forwarding will not be available."
    fi

    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        echo "Error: Container is not running"
        exit 1
    fi

    ### rmw_zenoh notice (remove later)
    print_rmw_zenoh_notice
    ### rmw_zenoh notice (remove later)

    docker exec -it "$CONTAINER_NAME" bash
}

### rmw_zenoh notice (remove later)
print_rmw_zenoh_notice() {
    W=52
    BAR=$(printf '%*s' $W '' | tr ' ' '=')
    LINE1="Since v1.0.0, rmw_zenoh_cpp is the default RMW."
    LINE2="RMW_IMPLEMENTATION is set in ~/.bashrc inside the"
    LINE3="container."
    echo ""
    echo "  +${BAR}+"
    printf "  |  %-$((W-2))s|\n" "$LINE1"
    printf "  |  %-$((W-2))s|\n" "$LINE2"
    printf "  |  %-$((W-2))s|\n" "$LINE3"
    echo "  +${BAR}+"
    echo ""
}
### rmw_zenoh notice (remove later)

# Function to stop the container
stop_container() {
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        echo "Error: Container is not running"
        exit 1
    fi

    echo "Warning: This will stop and remove the container. All unsaved data in the container will be lost."
    read -p "Are you sure you want to continue? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker compose -f "${SCRIPT_DIR}/docker-compose.yml" down
    else
        echo "Operation cancelled."
        exit 0
    fi
}

# Main command handling
case "$1" in
    "help")
        show_help
        ;;
    "start")
        start_container
        ;;
    "enter")
        enter_container
        ;;
    "stop")
        stop_container
        ;;
    *)
        echo "Error: Unknown command"
        show_help
        exit 1
        ;;
esac
