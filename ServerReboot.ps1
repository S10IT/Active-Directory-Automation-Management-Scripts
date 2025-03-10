###############################################################################
# Script Name:    ServerReboot.ps1
# Author:        Stan Livetsky
# Created Date:  2025-03-10
# Version:       1.0
# Description:   
#   This script reads a list of servers from a user-provided text file and 
#   reboots them sequentially. It logs the process, includes error handling, 
#   displays a countdown timer, and sends an email summary upon completion.
#
# Usage:
#   Run this script and provide the full path to a text file containing 
#   one server name per line.
#
# Requirements:
#   - PowerShell must be run with administrative privileges.
#   - SMTP server details must be configured.
#
###############################################################################

param (
    [string]$LogFilePath = "$env:USERPROFILE\Desktop\ServerRebootLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log",
    [string]$EmailRecipient = "admin@example.com",
    [string]$SMTPServer = "smtp.example.com"
)

# Function to log messages
function Write-Log {
    param (
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Message"
    Write-Host $LogEntry
    Add-Content -Path $LogFilePath -Value $LogEntry
}

# Function for countdown timer
function Start-Countdown {
    param (
        [int]$Seconds = 60
    )
    Write-Host "Waiting for $Seconds seconds before proceeding..."
    for ($i = $Seconds; $i -gt 0; $i--) {
        Write-Host "`rTime remaining: $i seconds" -NoNewline
        Start-Sleep -Seconds 1
    }
    Write-Host ""
}

# Main script execution
$StartDate = Get-Date
$ServerCount = 0

Clear-Host
Write-Host "Script started on $(Get-Date -Format 'F')"
Write-Log "Script execution started."

# Get file path from user
$FilePath = Read-Host "Please provide the path of the Server Restart text file"

if (Test-Path $FilePath) {
    $Servers = Get-Content $FilePath

    foreach ($Server in $Servers) {
        $ServerCount++

        Write-Log "Attempting to reboot: $Server"
        Write-Host "Rebooting server: $Server" -ForegroundColor Yellow

        try {
            Restart-Computer -ComputerName $Server -Wait -For WMI -Force -ErrorAction Stop
            Write-Log "Reboot command successfully sent to $Server"
        }
        catch {
            Write-Log "ERROR: Failed to reboot $Server - $_"
        }

        Start-Countdown -Seconds 60
    }

    $EndDate = Get-Date
    $Duration = New-TimeSpan -Start $StartDate -End $EndDate

    $Summary = @"
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; }
            h2 { color: #2e6c80; }
            table { width: 100%; border-collapse: collapse; }
            th, td { border: 1px solid black; padding: 8px; text-align: left; }
            th { background-color: #f2f2f2; }
        </style>
    </head>
    <body>
        <h2>Server Reboot Summary</h2>
        <p><strong>Start Time:</strong> $($StartDate)</p>
        <p><strong>End Time:</strong> $($EndDate)</p>
        <p><strong>Total Servers Processed:</strong> $($ServerCount)</p>
        <p><strong>Duration:</strong> $($Duration.Minutes) minutes</p>
        <p>See log file for details: $LogFilePath</p>
    </body>
    </html>
"@

    # Send Email Notification
    try {
        Send-MailMessage -To $EmailRecipient -From "noreply@example.com" -Subject "Server Reboot Summary" `
            -Body $Summary -BodyAsHtml -SmtpServer $SMTPServer
        Write-Log "Summary email sent successfully."
    }
    catch {
        Write-Log "ERROR: Failed to send email - $_"
    }

    Write-Log "Script execution completed successfully."
    Write-Host "All servers processed. Log saved at: $LogFilePath"
} else {
    Write-Log "ERROR: The file path provided does not exist."
    Write-Host "ERROR: No file found at the specified location!" -ForegroundColor Red
}