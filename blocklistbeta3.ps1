# Configuration parameters (with descriptive comments)
$BlocklistUrl = "http://lists.blocklist.de/lists/all.txt"  # Source of the blocklist
$RuleBaseName = "Blocklist.de"                            # Base name for firewall rules  
$MaxAddressesPerRule = 10000                              # Efficiency trade-off for rule limits

# Error handling with specific actions
try {
    # Check for existing rules 
    $ExistingRules = Get-NetFirewallRule -Name "$RuleBaseName-*" -ErrorAction Stop

    # Remove existing rules (provide confirmation option)
    if ($ExistingRules) {
        # Consider adding a -Confirm or -WhatIf switch here for safety
        $ExistingRules | Remove-NetFirewallRule 
        Write-Verbose "Existing firewall rules deleted."
    }

    # Download and process blocklist
    $BlocklistFile = New-TemporaryFile
    Invoke-WebRequest -Uri $BlocklistUrl -OutFile $BlocklistFile -ErrorAction Stop

    # Filter, sort, and deduplicate IP addresses
    $BlocklistLines = Get-Content $BlocklistFile | 
                      Where-Object { $_ -and $_ -notmatch "^#" } | # Filter comments
                      Sort-Object -Unique                           # Optimization and uniqueness

    Remove-Item $BlocklistFile # Cleanup

    # Batch rule creation with progress indication
    $BatchCount = [Math]::Ceiling($BlocklistLines.Count / $MaxAddressesPerRule)

    for ($i = 0; $i -lt $BatchCount; $i++) {
        $StartIndex = $i * $MaxAddressesPerRule
        $EndIndex = [Math]::Min(($i + 1) * $MaxAddressesPerRule - 1, $BlocklistLines.Count - 1)
        $RemoteAddresses = $BlocklistLines[$StartIndex..$EndIndex]

        $RuleName = "{0}-{1}" -f $RuleBaseName, $i

        # Consider writing progress info:
        Write-Progress -Activity "Creating firewall rules" -CurrentOperation $RuleName -PercentComplete (($i+1) / $BatchCount * 100)

        New-NetFirewallRule -Name $RuleName -DisplayName $RuleName `
                            -Description "Block IPs from blocklist.de" -Direction Inbound `
                            -Action Block -RemoteAddress $RemoteAddresses -ErrorAction Stop 
    }

    Write-Verbose "Firewall rules created successfully."

} catch [Net.Security.NetworkFirewall.RuleManagementException] {
    Write-Error "Firewall rule management error: $_" 
} catch {
    Write-Error "An unexpected error occurred: $_"
    # Add logging or more specific error handling here
} 
