# 1 - Manage Network Card

# 1.1 - Get network card details
# 1.1.A
Get-NetAdapter | Where-Object { ($_.Status -eq 'Up') }

# 1.1.B
$networkAdapter = Get-NetAdapter | Where-Object { ($_.Status -eq 'Up') -and ($_.InterfaceDescription -notlike '*Loopback*') }
$networkAdapter
$networkAdapter | select *



# 1.2 - Disable and enable IPv6 for a network adapter

# 1.2.A - Get network adapter bindings
Get-NetAdapterBinding -Name $networkAdapter.Name

# 1.2.B - Disable IPv6
Disable-NetAdapterBinding -Name $networkAdapter.Name -ComponentID ms_tcpip6

# 1.2.C - Enable IPv6
Enable-NetAdapterBinding -Name $networkAdapter.Name -ComponentID ms_tcpip6



# 1.3 - Set DNS IP addresses on a network card

# 1.3.A - Set DNS servers
$dnsServers = "8.8.8.8", "8.8.4.4"
Set-DnsClientServerAddress -InterfaceAlias $networkAdapter.Name -ServerAddresses $dnsServers

# 1.3.B - Set DNS setting to automatic
Set-DnsClientServerAddress -InterfaceAlias $networkAdapter.Name -ResetServerAddresses



# 1.4 - Set DNS suffix search order on a network card

# 1.4.A - Get existing DNS suffix list
Get-CimInstance -Class win32_networkadapterconfiguration | select -ExpandProperty dnsdomainsuffixsearchorder | select -Unique

# 1.4.B - Add DNS additional suffix to the list
[System.Collections.ArrayList]$SuffixList = @()
Get-CimInstance -Class win32_networkadapterconfiguration | select -ExpandProperty dnsdomainsuffixsearchorder | select -Unique | %{$SuffixList += $_}
"example.com", "internal.com" | %{$SuffixList += $_}

$SuffixString = ""
foreach ($Suffix in $SuffixList){
    $SuffixString += "$suffix,"
}
$SuffixString = $SuffixString.TrimEnd(",")

$SuffixListArray = @($SuffixString)

Invoke-CimMethod -ClassName win32_networkadapterconfiguration -MethodName "SetDNSSuffixSearchOrder" -Arguments @{
    DNSDomainSuffixSearchOrder=$SuffixListArray
}

# 1.4.C - Verify DNS suffix list after changes
Get-CimInstance -Class win32_networkadapterconfiguration | select -ExpandProperty dnsdomainsuffixsearchorder | select -Unique


#########################################################################################################

# 2 - Manage Local Disk

# 2.1 - Initialize a disk
Get-Disk
$diskNumber = 1  # Change this to the appropriate disk number
Initialize-Disk -Number $diskNumber -PartitionStyle MBR

# 2.2 - Create partition on the disk
New-Partition -DiskNumber $diskNumber -UseMaximumSize -AssignDriveLetter -IsActive | Format-Volume -FileSystem NTFS -NewFileSystemLabel "MyVolume"

# 2.3 - Remove Partition
Remove-Partition -DiskNumber 1 -PartitionNumber 1

# 2.4 - Create multiple partitions of different sizes
$partitionNumber = 0
$partitionSizes = @(1GB, 1GB, 500MB)  # Adjust sizes as needed
foreach ($size in $partitionSizes) {
    $partitionNumber++
    New-Partition -DiskNumber $diskNumber -Size $size | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Partition$partitionNumber"
}

# 2.5 - Resize partition and change drive letter
Get-Partition -DiskNumber 1

$resizePartitionNumber = 3  # Change this to the partition number you want to resize
$resizeSize = 1500MB  # Change this to the new size
Resize-Partition -DiskNumber $diskNumber -PartitionNumber $resizePartitionNumber -Size $resizeSize

Get-Partition -DiskNumber 1

# 2.6 - Change drive letter
$Hash = [Ordered]@{
    1 = "D"
    2 = "E"
    3 = "F"
}

foreach($Key in $Hash.keys)
{
    Write-Host "$Hash.$Key"
    Set-Partition -DiskNumber $diskNumber -PartitionNumber $Key -NewDriveLetter $Hash.$Key
}



#########################################################################################################

# 3 - Manage Event Logs

# 3.1 - Retrieve event logs
$allEventLogs = Get-EventLog -List

foreach ($log in $allEventLogs) {
    Write-Host $log.Log
}

# 3.2 - Retrieve specific event log
$specificLogName = "System"  # Change this to the desired log name
$specificEventLog = Get-EventLog -LogName $specificLogName -Newest 10

foreach ($event in $specificEventLog) {
    Write-Host "Event ID: $($event.EventID), Time: $($event.TimeGenerated), Message: $($event.Message)"
}

# 3.3 - Create event log
$newEventLogName = "CustomEventLog"  # Change this to the desired log name
$newEventLogSource = "MyScript"      # Change this to the desired source name

# Check if the event log exists, if not, create it
if (-not (Get-EventLog -LogName $newEventLogName -ErrorAction SilentlyContinue)) {
    New-EventLog -LogName $newEventLogName -Source $newEventLogSource
    Write-Host "Event Log '$newEventLogName' created with source '$newEventLogSource'."
} else {
    Write-Host "Event Log '$newEventLogName' already exists."
}

Get-EventLog -List

# 3.4 - Write an event to the newly created event log
Write-EventLog -LogName $newEventLogName -Source $newEventLogSource -EntryType Information -EventId 100 -Message "Custom event logged."



#########################################################################################################


# 4 - Manage Firewall

# 4.1 - Create, retrieve, disable, enable, modify, rename, and remove Windows Firewall rule
$ruleName = "MyFirewallRule"

# 4.1.A - Create a new firewall rule
New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80

# 4.1.B - Retrieve and display firewall rule details
$firewallRule = Get-NetFirewallRule -DisplayName $ruleName
$firewallRule

# 4.1.C - Disable the firewall rule
Disable-NetFirewallRule -DisplayName $ruleName

# 4.1.D - Enable the firewall rule
Enable-NetFirewallRule -DisplayName $ruleName

# 4.1.E - Modify the firewall rule (changing local and remote IP addresses)
$IP = (Get-NetIPAddress | Where-Object{($_.InterfaceAlias -eq "Ethernet 3") -and ($_.AddressFamily -eq "IPv4")}).IPAddress
Set-NetFirewallRule -DisplayName $ruleName -LocalPort 8080 -LocalAddress $IP -RemoteAddress "8.8.8.8","4.4.4.4","3.3.3.3"

# 4.1.F - Rename the firewall rule
Rename-NetFirewallRule -DisplayName $ruleName -NewName "RenamedFirewallRule"
Set-NetFirewallrule -DisplayName $ruleName -NewDisplayName "RenamedFirewallRule"

# 4.1.G - Remove the firewall rule
Remove-NetFirewallRule -DisplayName "RenamedFirewallRule"



# 4.2 - Allow ping ICMP traffic
Enable-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)"



# 4.3 - Change firewall profile status
# 4.3.A - Disable the Domain profile (you can replace 'Domain' with 'Public' or 'Private' if needed)
Set-NetFirewallProfile -Profile Domain -Enabled False
Get-NetFirewallProfile | select name, enabled

# 4.3.B - Enable the Domain profile
Set-NetFirewallProfile -Profile Domain -Enabled True



#########################################################################################################

# 5 - Manage PS Remoting

# 5.1.A - Manage trusted host
Enter-PSSession -ComputerName 172.31.24.21

# 5.1.B - Add the remote computer to the trusted hosts list
Get-Item WSMan:\localhost\Client\TrustedHosts
$remoteComputer = "172.31.24.21"
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $remoteComputer -Force

# 5.1.C - Display the updated trusted hosts list
Get-Item WSMan:\localhost\Client\TrustedHosts



# 5.2 - Access remote machine using PS remoting
$remoteSession = New-PSSession -ComputerName $remoteComputer
Invoke-Command -Session $remoteSession -ScriptBlock {
    $env:COMPUTERNAME
}

# 5.3 - Close the remote session
Remove-PSSession $remoteSession
