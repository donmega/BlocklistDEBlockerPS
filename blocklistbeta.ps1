# Configuration parameters
$blocklist_url = "http://lists.blocklist.de/lists/all.txt"
$rule_base_name = "Blocklist.de"
$max_addresses_per_rule = 10000  # Max IPs per rule for efficiency

# Error handling
try {
    # Check for existing rules
    $existingRules = Get-NetFirewallRule -Name "$rule_base_name-*" -ErrorAction Stop

    # Remove existing rules
    if ($existingRules) {
        $existingRules | Remove-NetFirewallRule
        Write-Host "Existing firewall rules deleted."
    }

    # Download and process blocklist
    $blocklist_file = New-TemporaryFile
    Invoke-WebRequest -Uri $blocklist_url -OutFile $blocklist_file -ErrorAction Stop

    $blocklist_lines = Get-Content $blocklist_file | Where-Object {$_ -and $_ -notmatch "^#"}
    $blocklist_lines = $blocklist_lines | Sort-Object -Unique

    # Remove temporary file
    Remove-Item $blocklist_file

    # Batch rule creation
    $batch_count = [Math]::Ceiling($blocklist_lines.Count / $max_addresses_per_rule)

    for ($i = 0; $i -lt $batch_count; $i++) {
        $start_index = $i * $max_addresses_per_rule
        $end_index = [Math]::Min(($i + 1) * $max_addresses_per_rule - 1, $blocklist_lines.Count - 1)
        $remote_addresses = $blocklist_lines[$start_index..$end_index]

        $rule_name = "$rule_base_name-$i"
        New-NetFirewallRule -Name $rule_name -DisplayName $rule_name -Description "Block IPs from blocklist.de" -Direction Inbound -Action Block -RemoteAddress $remote_addresses -ErrorAction Stop
    }

    Write-Host "Firewall rules created successfully."
} catch {
    Write-Error "An error occurred: $_"
} 
