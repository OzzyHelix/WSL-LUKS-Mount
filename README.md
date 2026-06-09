>Warning: Use at your own risk. This software is **EXPERIMENTAL** and is not advised for use in production systems. Backing up your data before use is strongly recommended.


# WSL-LUKS-Mount

Scripts and documentation for mounting LUKS-encrypted Linux drives in Windows 11 through WSL.

## Included Scripts

* `mount_luks.ps1`

---

# Important Requirements

Before using this setup, your Windows installation must be located on a drive that is separate from the Linux drives you intend to access through WSL.

### Supported Configuration

Windows EFI/System partition on its own drive

Linux LUKS-encrypted drives on separate physical drives. LUKS encrypted partitions can also be shared on the same drive its just the case that Windows partitions can't

### Unsupported Configuration

Windows and Linux sharing the same physical drive

WSL disk pass-through does not work reliably when Windows and Linux partitions reside on the same disk.

---

# Introduction

This guide explains how to configure Windows Subsystem for Linux (WSL) to automatically mount and unlock LUKS-encrypted Linux partitions from Windows 11.

The provided PowerShell script passes physical drives directly into WSL, opens the LUKS containers, and allows the filesystems to be mounted automatically through `/etc/fstab`.

---

# Prerequisites

Before continuing, ensure you have:

* Windows 11 / Windows 10
* WSL2 installed
* An Ubuntu WSL distribution (recommended)
* One or more LUKS-encrypted Linux drives
* Administrator access in Windows

---

# Configure WSL

## Edit `.wslconfig`

Create or edit:

```text
%USERPROFILE%\.wslconfig
```

Add the following:

```ini
[wsl2]
vmIdleTimeout=-1
networkingMode=mirrored
dnsTunneling=true
autoProxy=true
```

### Why These Settings?

Windows will often pause or shut down WSL when it becomes idle in order to save system resources.
there are also options there that make wsl share the network with your host so in theory you can use network drive mapping to share between wsl and the host

Setting:

```ini
vmIdleTimeout=-1
```

prevents WSL from automatically stopping, which helps keep mounted drives available.

---

## Configure `/etc/wsl.conf`

Inside your WSL distribution, edit:

```bash
sudo nano /etc/wsl.conf
```

Example configuration:

```ini
[boot]
systemd=true

[user]
default=youruser

[automount]
enabled=true
mountFsTab=true
```

### Why This Is Needed

These settings enable:

* Systemd support
* Automatic mounting through `/etc/fstab`
* Persistent mount points after drive unlock

---

# Configure `/etc/fstab`

Example:

```fstab
# /etc/fstab

/dev/mapper/crypt_drive2   /mnt/games      ext4   defaults,noatime,nofail   0 2
/dev/mapper/crypt_home     /mnt/archhome   ext4   defaults,noatime,nofail   0 2
```

This example assumes the encrypted volumes contain ext4 filesystems.

The names used in `/dev/mapper/` must match the names configured in `mount_luks.ps1`.

For example:

```text
/dev/mapper/crypt_home
```

must match the mapper name created by the script.

---

# Finding Your Windows Physical Drive

Open an Administrator PowerShell window and run:

```powershell
Get-CimInstance -Query "SELECT * FROM Win32_DiskDrive"
```

Example output:

```text
DeviceID           Caption                    Partitions Size
--------           -------                    ---------- ----
\\.\PHYSICALDRIVE0 SKHynix_HFS512GD9TNI-L2A0B 2          512105932800
\\.\PHYSICALDRIVE1 Patriot P400L 2000GB       1          2000396321280
\\.\PHYSICALDRIVE2 Samsung SSD 980 PRO 1TB    3          1000202273280
\\.\PHYSICALDRIVE3 Samsung SSD 9100 PRO 4TB   1          4000784417280
```

Identify the physical drive that contains the LUKS partition you want to mount.

You will use this value later in the script configuration.

Example:

```powershell
\\.\PHYSICALDRIVE1
```

---

# Finding the LUKS UUID

First, attach the drive to WSL:

```powershell
wsl.exe --mount \\.\PHYSICALDRIVE1 --bare
```

Replace `PHYSICALDRIVE1` with your drive number.

Next, enter WSL:

```powershell
wsl
```

List available block devices:

```bash
lsblk
```

Example:

```text
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
sde      8:64   0 1.8T 0 disk
└─sde1   8:65   0 1.8T 0 part

sdf      8:80   0 3.6T 0 disk
└─sdf1   8:81   0 3.6T 0 part
```

Identify the partition containing the LUKS volume and obtain its UUID:

```bash
sudo blkid /dev/sdf1
```

Example output:

```text
/dev/sdf1: UUID="4eee4b7c-c254-425b-9bd2-b7a4119118f7" TYPE="crypto_LUKS" PARTUUID="c0ac116f-33bc-4ae9-b63b-72d02224f80b"
```

**Use the UUID value, not the PARTUUID value.**

Example:

```text
4eee4b7c-c254-425b-9bd2-b7a4119118f7
```

---

# Configure `mount_luks.ps1`

Edit the configuration section:

```powershell
# ==========================================
# CONFIGURATION
# ==========================================

$WslDistro = "Ubuntu"

# Windows Drive Identifiers
$Drive2          = "\\.\PHYSICALDRIVE1"
$SharedPartition = "\\.\PHYSICALDRIVE3"

# Linux LUKS UUIDs
$UuidDrive2 = "f4a43c1a-3817-4c62-b7b5-407387abe41b"
$UuidHome   = "4eee4b7c-c254-425b-9bd2-b7a4119118f7"

# WSL Mount Points
$Mnt2    = "/mnt/games"
$MntHome = "/mnt/archhome"
```

Replace the values with the information gathered in the previous steps.

---

# Running the Script

Open an Administrator PowerShell window and run:

```powershell
.\mount_luks.ps1
```
this assumes you are in the same directory as the script when running it in powershell

The script will:

1. Pass the physical drives into WSL.
2. Detect the LUKS volumes.
3. Prompt for decryption passwords if required.
4. Open the encrypted containers.
5. Allow WSL to mount the filesystems using `/etc/fstab`.

---

# Accessing the Mounted Drives

Once mounted, the files can be accessed through:

```text
\\wsl.localhost\Ubuntu
```

Navigate to the mount points you configured.

Example:

```text
\\wsl.localhost\Ubuntu\mnt\games
\\wsl.localhost\Ubuntu\mnt\archhome
```

---

# Optional: Run Automatically at Login

You can create a Windows Scheduled Task that runs `mount_luks.ps1` when you log in.

This allows your encrypted Linux drives to be automatically attached and mounted whenever Windows starts.

# Optional: Configure Samba for Network Drive Access

If you prefer to access your mounted Linux drives through standard Windows network shares, you can run Samba inside WSL.

An example `smb.conf` file is included with this project.

---

## Install Samba

Inside your WSL distribution, install Samba:

```bash
sudo apt update
sudo apt install samba
```

---

## Configure Samba

Copy the included configuration file into place:

```bash
sudo cp smb.conf /etc/samba/smb.conf
```

You can edit the file later to match your own mount points and share names.

Example:

```ini
[Games]
path = /mnt/games

[ArchHome]
path = /mnt/archhome
```

---

## Create a Network Bridge for WSL

By default, WSL uses NAT networking, which can make Samba shares difficult to access from other devices on your network.

Create a Hyper-V virtual switch in an Administrator PowerShell window:

```powershell
New-VMSwitch -Name "wsl-bridge" -NetAdapterName "Ethernet" -AllowManagementOS $true
```

Replace `"Ethernet"` with the name of your active network adapter if necessary.

---

## Configure WSL to Use the Bridge

Edit:

```text
%USERPROFILE%\.wslconfig
```

Example configuration:

```ini
[wsl2]
vmIdleTimeout=-1
networkingMode=bridged
vmSwitch=wsl-bridge
dnsTunneling=true
autoProxy=true
```

After saving the file, restart WSL:

```powershell
wsl --shutdown
```

Then start your WSL distribution again.

---

## Assign a Static IP Address (Recommended)

Using bridged networking allows WSL to appear as its own device on your local network.

For Samba shares, it is recommended to assign a static IP address so Windows drive mappings remain consistent after reboots.

You can configure this through your router's DHCP reservation settings or by manually configuring networking inside WSL.

---

## Enable Samba

Start Samba and configure it to start automatically when WSL launches:

```bash
sudo systemctl enable --now smbd
```

Verify that Samba is running:

```bash
sudo systemctl status smbd
```

---

## Create a Samba User

Create a Samba password for your Linux user account:

```bash
sudo smbpasswd -a <username>
```

Example:

```bash
sudo smbpasswd -a ozzy
```

This username and password will be used when connecting to the Samba share from Windows.

---

## Access the Shares from Windows

Once Samba is running, open File Explorer and browse to:

```text
\\<WSL-IP-ADDRESS>\
```

Example:

```text
\\192.168.1.100\
```

You should see the shares defined in your `smb.conf` file.

To map a share as a network drive:

1. Open File Explorer.
2. Right-click **This PC**.
3. Select **Map network drive**.
4. Enter the share path.
5. Provide your Samba username and password when prompted.

Example share paths:

```text
\\192.168.1.100\Games
\\192.168.1.100\ArchHome
```

Your mounted LUKS volumes can now be accessed through standard Windows network drives and from other devices on your local network.
