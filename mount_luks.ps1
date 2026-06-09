# ==========================================
# CONFIGURATION
# ==========================================
$WslDistro      = "Ubuntu"

# Windows Hard Drive/Partition Identifiers
$Drive2          = "\\.\PHYSICALDRIVE1"
$SharedPartition = "\\.\PHYSICALDRIVE3"

# Linux LUKS UUIDs
$UuidDrive2      = "f4a43c1a-3817-4c62-b7b5-407387abe41b"
$UuidHome        = "4eee4b7c-c254-425b-9bd2-b7a4119118f7"

# Target Mount Points inside WSL
$Mnt2            = "/mnt/games"
$MntHome         = "/mnt/archhome"

# ------------------------------------------
# ENVIRONMENT FIXED PATH RESOLUTION
# ------------------------------------------
# Task Scheduler often drops System32 from the PATH or redirects to SysWOW64.
# This forces the absolute 64-bit native execution path for WSL.
if (Test-Path "$env:windir\Sysnative\wsl.exe") {
    $WslPath = "$env:windir\Sysnative\wsl.exe"
} else {
    $WslPath = "$env:windir\System32\wsl.exe"
}

# Force set critical environment variables that WSL interop needs
$env:PATH = "$env:SystemRoot\system32;$env:SystemRoot;$env:SystemRoot\System32\Wbem;" + $env:PATH
$env:WSL_UTF8 = 1

# Ensure our working directory is stable and safe
Set-Location -Path $env:TEMP

# ------------------------------------------
# 1. Attach hardware to WSL
# ------------------------------------------
Write-Host "Attaching disks to WSL using absolute binary path..."
& $WslPath --mount $Drive2 --bare
& $WslPath --mount $SharedPartition --bare

# ------------------------------------------
# 2. Dynamically Wait for Linux Device Paths
# ------------------------------------------
Write-Host "Waiting for Linux kernel to populate disk UUID symlinks..."
& $WslPath -d $WslDistro -u root -- bash -c "
    for i in {1..15}; do
        if [ -L '/dev/disk/by-uuid/$UuidDrive2' ] && \
           [ -L '/dev/disk/by-uuid/$UuidHome' ]; then
            echo 'All hardware block device paths ready!'
            exit 0
        fi
        echo 'Waiting for kernel symlinks... (retry \$i/15)'
        sleep 1
    done
    echo 'Timed out waiting for disk UUIDs.' >&2
    exit 1
"

# Exit out early if the kernel failed to pass the hardware mapping through
if ($LASTEXITCODE -ne 0) {
    Write-Error "WSL failed to register disk UUIDs in a timely manner. Aborting mount."
    Exit 1
}

# ------------------------------------------
# 3. Unlock and Mount via UUIDs
# ------------------------------------------
Write-Host "Unlocking and mounting LUKS volumes securely via UUID..."
& $WslPath -d $WslDistro -u root -- bash -c "

    # Drive 2
    cryptsetup luksOpen /dev/disk/by-uuid/$UuidDrive2 crypt_drive2
    mkdir -p $Mnt2 && mount /dev/mapper/crypt_drive2 $Mnt2

    # Shared Home Partition
    cryptsetup luksOpen /dev/disk/by-uuid/$UuidHome crypt_home
    mkdir -p $MntHome && mount /dev/mapper/crypt_home $MntHome
"
Write-Host "All drives mounted successfully!"

# ------------------------------------------
# 4. Force Windows Explorer to See the Mounts
# ------------------------------------------
& $WslPath -d $WslDistro ls /mnt/games > $null
& $WslPath -d $WslDistro ls /mnt/archhome > $null