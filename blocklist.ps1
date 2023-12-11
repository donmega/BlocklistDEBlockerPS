# Define the URL of the blocklist file
$blocklist_url = "http://lists.blocklist.de/lists/all.txt"

# Define the base name of the firewall rule
$rule_base_name = "Blocklist.de"

# Download the blocklist file and save it as a temporary file
$blocklist_file = New-TemporaryFile
Invoke-WebRequest -Uri $blocklist_url -OutFile $blocklist_file

# Read the blocklist file and split it into lines
$blocklist_lines = Get-Content $blocklist_file

# Remove any empty lines or comments
$blocklist_lines = $blocklist_lines | Where-Object {$_ -and $_ -notmatch "^#"}

# Sort the blocklist lines and remove any duplicates
$blocklist_lines = $blocklist_lines | Sort-Object -Unique

# Delete the temporary file
Remove-Item $blocklist_file

# Check if the firewall rule already exists
$rule = Get-NetFirewallRule -Name $rule_base_name -ErrorAction SilentlyContinue

# If the rule exists, delete it
if ($rule) {
    Remove-NetFirewallRule -Name $rule_base_name
}

# Create a new firewall rule with the blocklist lines as remote addresses
# Split the blocklist lines into batches of 10000 to avoid exceeding the limit
$batch_size = 10000
$batch_count = [Math]::Ceiling($blocklist_lines.Count / $batch_size)

for ($i = 0; $i -lt $batch_count; $i++) {
    $start_index = $i * $batch_size
    $end_index = [Math]::Min(($i + 1) * $batch_size - 1, $blocklist_lines.Count - 1)
    $remote_addresses = $blocklist_lines[$start_index..$end_index]

    $rule_name = "$rule_base_name-$i"
    New-NetFirewallRule -Name $rule_name -DisplayName $rule_name -Description "Block IPs from blocklist.de" -Direction Inbound -Action Block -RemoteAddress $remote_addresses
}
