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
