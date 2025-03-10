<# 
    ==========================================================================================
    Script Name: TLS_Status_Check.ps1
    Description: Checks enabled TLS versions on all Domain Controllers and generates an HTML report sent via email.
    Version:     1.0
    Author:      Stan Livetsky
    Date:        2025-03-10
    ==========================================================================================
    Change Log:
    ------------------------------------------------------------------------------------------
    Version 1.0 - Initial script to check TLS versions and send an HTML email report.
    ==========================================================================================
#>

# Define SMTP settings
$SMTPServer = "your.smtp.server" # Replace with your SMTP server
$From = "no-reply@yourdomain.com" # Replace with sender email
$To = "admin@yourdomain.com" # Replace with recipient email
$Subject = "TLS Status Report for Domain Controllers"

# Get all Domain Controllers
$DCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName

# Registry paths for TLS settings
$TLSPaths = @(
    "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server",
    "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server",
    "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"
)

# Function to check registry values
function Get-TLSStatus {
    param (
        [string]$ComputerName
    )

    $TLSStatus = @()
    foreach ($TLSPath in $TLSPaths) {
        $TLSVersion = $TLSPath -match 'TLS\s(\d\.\d)' | Out-Null; $Version = $matches[1]
        $Enabled = $null
        $DisabledByDefault = $null

        # Query registry remotely
        try {
            $Enabled = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                param ($TLSPath)
                Get-ItemProperty -Path $TLSPath -Name "Enabled" -ErrorAction SilentlyContinue
            } -ArgumentList $TLSPath

            $DisabledByDefault = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                param ($TLSPath)
                Get-ItemProperty -Path $TLSPath -Name "DisabledByDefault" -ErrorAction SilentlyContinue
            } -ArgumentList $TLSPath
        } catch {
            Write-Host "Unable to query $ComputerName for $TLSPath"
        }

        $TLSStatus += [PSCustomObject]@{
            'DC Name'           = $ComputerName
            'TLS Version'       = $Version
            'Enabled'           = if ($Enabled.Enabled -eq 1) { "Enabled" } else { "Disabled" }
            'DisabledByDefault' = if ($DisabledByDefault.DisabledByDefault -eq 0) { "Enabled" } else { "Disabled" }
        }
    }
    return $TLSStatus
}

# Collect TLS status from all DCs
$Results = @()
foreach ($DC in $DCs) {
    $Results += Get-TLSStatus -ComputerName $DC
}

# Export results to CSV
$CSVPath = "$env:USERPROFILE\TLS_Status_Report.csv"
$Results | Export-Csv -Path $CSVPath -NoTypeInformation

# Generate HTML Report with Custom Text
$HTMLReport = @"
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; font-size: 12px; }
        table { border-collapse: collapse; width: 100%; font-size: 12px; }
        th, td { border: 1px solid black; padding: 6px; text-align: left; }
        th { background-color: #f2f2f2; font-size: 14px; }
        .enabled { background-color: #d4edda; }  /* Light green */
        .disabled { background-color: #f8d7da; } /* Light red */
    </style>
</head>
<body>

    <h2 style="font-size: 16px;">TLS Status Report for Domain Controllers</h2>

    <p>Hello,</p>
    <p>This is an automated report providing the current TLS settings for all domain controllers in your environment. Please review the details below to ensure compliance with security standards.</p>

    <table>
        <tr>
            <th>DC Name</th>
            <th>TLS Version</th>
            <th>Enabled</th>
            <th>Disabled By Default</th>
        </tr>
"@

foreach ($Entry in $Results) {
    $EnabledClass = if ($Entry.Enabled -eq "Enabled") { "enabled" } else { "disabled" }
    $DisabledByDefaultClass = if ($Entry.DisabledByDefault -eq "Enabled") { "enabled" } else { "disabled" }

    $HTMLReport += @"
        <tr>
            <td>$($Entry.'DC Name')</td>
            <td>$($Entry.'TLS Version')</td>
            <td class='$EnabledClass'>$($Entry.Enabled)</td>
            <td class='$DisabledByDefaultClass'>$($Entry.'DisabledByDefault')</td>
        </tr>
"@
}

$HTMLReport += @"
    </table>

    <p>If you find any non-compliant settings, please take the necessary action to update TLS configurations as per your security policies.</p>
    <p>For any questions, contact the IT security team.</p>

    <p>Best Regards,<br>IT Operations Team</p>

</body>
</html>
"@

# Save HTML report to a file
$HTMLPath = "$env:USERPROFILE\TLS_Status_Report.html"
$HTMLReport | Out-File -Encoding utf8 -FilePath $HTMLPath

# Send Email with HTML Report
Send-MailMessage -To $To -From $From -Subject $Subject -SmtpServer $SMTPServer -BodyAsHtml $HTMLReport
Write-Host "TLS Status report sent to $To"