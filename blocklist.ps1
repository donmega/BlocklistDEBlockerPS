# Define the URL of the blocklist.de file
$blocklistUrl = "https://lists.blocklist.de/lists/all.txt"

# Define the path where the blocklist file will be downloaded
$downloadPath = "$env:TEMP\blocklist.txt"

# Define the Windows Firewall rule name
$firewallRuleNamePrefix = "Blocklist.de Rule"

# Download the blocklist file
Invoke-WebRequest -Uri $blocklistUrl -OutFile $downloadPath

# Read the downloaded file and filter out empty lines and comments
$ipAddresses = Get-Content $downloadPath | Where-Object { $_ -match '\d+\.\d+\.\d+\.\d+' }

# Check if there are existing firewall rules with the specified name and delete them
Get-NetFirewallRule | Where-Object { $_.DisplayName -like "$firewallRuleNamePrefix*" } | Remove-NetFirewallRule

# Define the maximum number of IP addresses per rule
$maxAddressesPerRule = 10000

# Split the IP addresses into batches of $maxAddressesPerRule
$ipBatches = @{}
foreach ($ip in $ipAddresses) {
    $batchNumber = [math]::floor($ipAddresses.IndexOf($ip) / $maxAddressesPerRule)
    $ipBatches[$batchNumber] += $ip
}

# Create a new firewall rule for each batch of IP addresses
foreach ($batchNumber in $ipBatches.Keys) {
    $ipAddressesInBatch = $ipBatches[$batchNumber]
    
    # Convert the IP addresses in batch to a valid format (IPv4 address range)
    $ipAddressRange = $ipAddressesInBatch | ForEach-Object {
        $ip = $_ -split '\.'
        "{0}.{1}.{2}.0-{0}.{1}.{2}.255" -f $ip[0], $ip[1], $ip[2]
    } | Sort-Object -Unique

    # Create a new firewall rule
    $ruleDisplayName = "$firewallRuleNamePrefix $batchNumber"
    New-NetFirewallRule -DisplayName $ruleDisplayName -Direction Inbound -RemoteAddress $ipAddressRange -Action Block
}

# Remove the downloaded blocklist file
Remove-Item $downloadPath

Write-Host "Blocklist.de firewall rules updated successfully."
