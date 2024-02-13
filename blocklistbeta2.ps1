# Configuration parameters
$BlocklistUrl = "http://lists.blocklist.de/lists/all.txt"
$RuleBaseName = "Blocklist.de"
$MaxAddressesPerRule = 10000  # Max IPs per rule for efficiency

# Error handling
try {
    # Check for existing rules
    $ExistingRules = Get-NetFirewallRule -Name "$RuleBaseName-*" -ErrorAction Stop

    # Remove existing rules
    if ($ExistingRules) {
        $ExistingRules | Remove-NetFirewallRule
        Write-Verbose "Existing firewall rules deleted."
    }

    # Download and process blocklist
    $BlocklistFile = New-TemporaryFile
    Invoke-WebRequest -Uri $BlocklistUrl -OutFile $BlocklistFile -ErrorAction Stop

    $BlocklistLines = Get-Content $BlocklistFile |
                      Where-Object {$_ -and $_ -notmatch "^#"} |
                      Sort-Object -Unique

    # Remove temporary file
    Remove-Item $BlocklistFile

    # Batch rule creation
    $BatchCount = [Math]::Ceiling($BlocklistLines.Count / $MaxAddressesPerRule)

    $CreateFirewallRule = {
        param($RuleName, $RemoteAddresses)
        New-NetFirewallRule -Name $RuleName -DisplayName $RuleName `
            -Description "Block IPs from blocklist.de" -Direction Inbound `
            -Action Block -RemoteAddress $RemoteAddresses -ErrorAction Stop
    }

    for ($i = 0; $i -lt $BatchCount; $i++) {
        $StartIndex = $i * $MaxAddressesPerRule
        $EndIndex = [Math]::Min(($i + 1) * $MaxAddressesPerRule - 1, $BlocklistLines.Count - 1)
        $RemoteAddresses = $BlocklistLines[$StartIndex..$EndIndex]

        $RuleName = "{0}-{1}" -f $RuleBaseName, $i
        & $CreateFirewallRule $RuleName $RemoteAddresses
    }

    Write-Verbose "Firewall rules created successfully."
} catch [Net.Security.NetworkFirewall.RuleManagementException] {
    Write-Error "Firewall rule management error: $_"
} catch {
    Write-Error "An unexpected error occurred: $_"
}
