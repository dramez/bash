# VM Shutdown/Save Script for CachyOS/Arch Linux

This script automates the process of saving or shutting down KVM virtual machines during system shutdown or reboot in CachyOS and Arch Linux. It ensures that running VMs are either saved or gracefully shut down before the host system powers off or restarts, preventing data loss and ensuring a smooth transition.

## Features

-   Saves the state of running VMs by default.
-   Gracefully shuts down VMs if saving fails.
-   Destroys VMs as a last resort if both saving and shutdown fail.
-   Logs actions taken for each VM to a log file.
-   Configurable timeouts for save and shutdown operations.
-   Only logs events where a VM's state is changed.

## Prerequisites

-   CachyOS or Arch Linux installed.
-   KVM and libvirt installed and configured.
-   `libvirtd` service enabled and running.

## Installation

1.  **Create the Script File:**

    Create the script file at `/usr/local/bin/vm-shutdown.sh`:

    ```bash
    sudo nano /usr/local/bin/vm-shutdown.sh
    ```

2.  **Copy the Script Content:**

    Copy the following script content into the file:

    ```bash
    #!/bin/bash
    LOG_FILE="/var/log/vm-shutdown.log"
    VM_SAVE_DIR="/var/lib/libvirt/qemu/save"
    SAVE_TIMEOUT=60  # Timeout for saving in seconds
    SHUTDOWN_TIMEOUT=30 # Timeout for shutdown in seconds

    # Function to log messages
    log() {
        echo "$(date) -\$1" >> "$LOG_FILE"
    }

    log "Starting VM shutdown/save process"

    # Ensure the save directory exists
    mkdir -p "$VM_SAVE_DIR"

    for VM_NAME in $(virsh list --all --name); do
        VM_STATE=$(virsh domstate "$VM_NAME")

        if [[ "$VM_STATE" == "running" ]]; then
            log "VM: $VM_NAME is running. Attempting to save state."
            SAVE_FILE="$VM_SAVE_DIR/$VM_NAME.save"

            (timeout $SAVE_TIMEOUT virsh save "$VM_NAME" "$SAVE_FILE") &
            SAVE_PID=$!
            wait "$SAVE_PID"
            SAVE_RESULT=$?

            if [ "$SAVE_RESULT" -ne 0 ]; then
                log "VM $VM_NAME failed to save state. Attempting graceful shutdown."

                (timeout $SHUTDOWN_TIMEOUT virsh shutdown "$VM_NAME") &
                SHUTDOWN_PID=$!
                wait "$SHUTDOWN_PID"
                SHUTDOWN_RESULT=$?

                if [ "$SHUTDOWN_RESULT" -ne 0 ]; then
                    log "VM $VM_NAME did not shut down gracefully. Attempting to destroy."
                    virsh destroy "$VM_NAME"
                    DESTROY_RESULT=$?

                    if [ "$DESTROY_RESULT" -ne 0 ]; then
                        log "ERROR: Failed to destroy VM $VM_NAME. Return code: $DESTROY_RESULT"
                    else
                        log "Successfully destroyed VM $VM_NAME"
                    fi
                else
                    log "Successfully shut down VM: $VM_NAME"
                fi
            else
                log "Successfully saved VM state for $VM_NAME to $SAVE_FILE"
            fi
        elif [[ "$VM_STATE" == "paused" ]]; then
            log "VM: $VM_NAME is paused. Saving state."
            SAVE_FILE="$VM_SAVE_DIR/$VM_NAME.save"

            (timeout $SAVE_TIMEOUT virsh save "$VM_NAME" "$SAVE_FILE") &
            SAVE_PID=$!
            wait "$SAVE_PID"
            SAVE_RESULT=$?

            if [ "$SAVE_RESULT" -ne 0 ]; then
                log "ERROR: Failed to save paused VM state for $VM_NAME. Attempting to destroy."
                virsh destroy "$VM_NAME"
                DESTROY_RESULT=$?

                if [ "$DESTROY_RESULT" -ne 0 ]; then
                    log "ERROR: Failed to destroy VM $VM_NAME. Return code: $DESTROY_RESULT"
                else
                    log "Successfully destroyed VM $VM_NAME"
                fi
            else
                log "Successfully saved VM state for $VM_NAME to $SAVE_FILE"
            fi
        else
            # No logging for VMs that are not running or paused
            continue
        fi
    done

    log "VM shutdown/save process complete"

    exit 0
    ```

3.  **Make the Script Executable:**

    ```bash
    sudo chmod +x /usr/local/bin/vm-shutdown.sh
    ```

4.  **Create Log File and Save Directory:**

    ```bash
    sudo touch /var/log/vm-shutdown.log
    sudo mkdir -p /var/lib/libvirt/qemu/save
    sudo chown libvirt-qemu:libvirt /var/log/vm-shutdown.log
    sudo chown libvirt-qemu:libvirt /var/lib/libvirt/qemu/save
    ```

5.  **Create Systemd Service File:**

    Create a systemd service file at `/etc/systemd/system/vm-shutdown.service`:

    ```bash
    sudo nano /etc/systemd/system/vm-shutdown.service
    ```

6.  **Copy Service Configuration:**

    Copy the following configuration into the service file:

    ```ini
    [Unit]
    Description=Shutdown/Save KVM VMs before system shutdown/reboot
    Before=halt.target poweroff.target reboot.target
    Requires=libvirtd.service
    After=libvirtd.service

    [Service]
    Type=oneshot
    ExecStart=/usr/local/bin/vm-shutdown.sh
    TimeoutSec=infinity
    RemainAfterExit=yes

    [Install]
    WantedBy=halt.target poweroff.target reboot.target
    ```

7.  **Enable and Start the Systemd Service:**

    ```bash
    sudo systemctl enable vm-shutdown.service
    sudo systemctl start vm-shutdown.service
    ```

8.  **Reload Systemd Daemon:**

    ```bash
    sudo systemctl daemon-reload
    ```

## Configuration

-   **Script Variables:**
    -   `LOG_FILE`: Path to the log file.
    -   `VM_SAVE_DIR`: Directory where VM states are saved.
    -   `SAVE_TIMEOUT`: Timeout in seconds for saving a VM's state.
    -   `SHUTDOWN_TIMEOUT`: Timeout in seconds for gracefully shutting down a VM.

## Usage

The script runs automatically during system shutdown or reboot. It iterates through all defined VMs, saves the state of running VMs, and logs the actions taken.

## Troubleshooting

-   **Check the Log File:**
    -   If VMs are not being saved or shut down as expected, check `/var/log/vm-shutdown.log` for any error messages.
-   **Permissions:**
    -   Ensure that the `libvirt-qemu` user has the necessary permissions to execute `virsh` commands and write to the log file and save directory.
-   **Service Status:**
    -   Check the status of the `vm-shutdown.service` using `systemctl status vm-shutdown.service` to ensure it is running without errors.
-   **Manual Execution:**
    -   You can manually run the script to test it: `sudo /usr/local/bin/vm-shutdown.sh`

## Uninstallation

1.  **Stop and Disable the Systemd Service:**

    ```bash
    sudo systemctl stop vm-shutdown.service
    sudo systemctl disable vm-shutdown.service
    ```

2.  **Remove the Service File:**

    ```bash
    sudo rm /etc/systemd/system/vm-shutdown.service
    ```

3.  **Remove the Script File:**

    ```bash
    sudo rm /usr/local/bin/vm-shutdown.sh
    ```

4.  **Remove the Log File and Save Directory (Optional):**

    ```bash
    sudo rm /var/log/vm-shutdown.log
    sudo rm -r /var/lib/libvirt/qemu/save
    ```

## Credits

-   This script was created to automate VM shutdown/save processes in CachyOS and Arch Linux.
