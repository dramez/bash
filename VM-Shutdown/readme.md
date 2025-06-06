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

    Copy file vm-shutdown.sh to your local system. Full path is: /usr/local/bin/vm-shutdown.sh

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
