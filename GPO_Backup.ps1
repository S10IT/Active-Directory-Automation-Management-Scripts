##########################################################################
# Script Name:    GPO_Backup.ps1
# Description:    This script backs up all Group Policy Objects (GPOs) 
#                using their friendly names. The backups are saved 
#                locally and remotely, with real-time status updates 
#                displayed on the screen and logged to a file.
# Author:         Stan Livetsky
# Date:           2025-03-10
# Version:        1.0
# Notes:          - Ensure administrative privileges to run the script.
#                - Update the local and remote backup paths as needed.
#                - Requires the Group Policy module.
##########################################################################

# Define backup locations
$LocalBackupPath = "C:\GPO_Backups"
$RemoteBackupPath = "\\RemoteServer\GPO_Backups"
$LogFile = "C:\GPO_Backups\GPO_Backup_Log.txt"

# Create backup folders if they don’t exist
foreach ($Path in @($LocalBackupPath, $RemoteBackupPath)) {
    if (!(Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

# Get list of all GPOs
$GPOs = Get-GPO -All

# Log and display function
function Log-Message {
    param ($Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Message"
    Write-Output $LogEntry
    Add-Content -Path $LogFile -Value $LogEntry
}

# Backup each GPO
foreach ($GPO in $GPOs) {
    $GPOName = $GPO.DisplayName
    $BackupLocalPath = Join-Path -Path $LocalBackupPath -ChildPath $GPOName
    $BackupRemotePath = Join-Path -Path $RemoteBackupPath -ChildPath $GPOName

    # Ensure directories exist
    foreach ($BackupPath in @($BackupLocalPath, $BackupRemotePath)) {
        if (!(Test-Path -Path $BackupPath)) {
            New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
        }
    }

    # Backup to local path
    try {
        Backup-GPO -Name $GPOName -Path $BackupLocalPath -ErrorAction Stop
        Log-Message "Successfully backed up '$GPOName' to '$BackupLocalPath'"
    } catch {
        Log-Message "Failed to back up '$GPOName' to '$BackupLocalPath' - Error: $_"
    }

    # Copy to remote location
    try {
        Copy-Item -Path "$BackupLocalPath\*" -Destination $BackupRemotePath -Recurse -Force -ErrorAction Stop
        Log-Message "Successfully copied '$GPOName' backup to '$BackupRemotePath'"
    } catch {
        Log-Message "Failed to copy '$GPOName' to '$BackupRemotePath' - Error: $_"
    }
}

Log-Message "GPO backup process completed."
Write-Output "GPO backup process completed. Check log file: $LogFile"