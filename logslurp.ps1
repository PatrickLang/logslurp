Param(
  [string]$win_user,
  [string]$win_pass
)

# Constants
$lockedFiles = "kubelet.err.log", "kubelet.log", "kubeproxy.log", "kubeproxy.err.log"
$netDebugFiles = "network.txt", "endpoint.txt", "policy.txt", "ip.txt", "ports.txt", "routes.txt", "vfpOutput.txt"

# Handle credentials as parameters, else prompt for them
if (($PSBoundParameters.ContainsKey("win_user")) -and ($PSBoundParameters.ContainsKey("win_pass")))
{ 
   $passwd = ConvertTo-SecureString $win_pass -AsPlainText -Force
   $cred = New-Object System.Management.Automation.PSCredential ($win_user, $passwd) 
}
else {
   $cred = Get-Credential -Message "Please enter an admin username & password to connect to the Windows nodes"
}


$nodes = ./kubectl get node -o json | ConvertFrom-Json
$nodes.items | Where-Object { $_.metadata.labels.'beta.kubernetes.io/os' -eq 'windows' } | foreach-object {
  Add-Member -InputObject $_ -MemberType NoteProperty -Name "pssession" -Value (New-PSSession -ComputerName $_.status.nodeInfo.machineID -Credential $cred -UseSSL -Authentication basic)
  Write-Host Connected to $_.status.nodeInfo.machineID
  # Write-Host Logs:
  $timeStamp = get-date -format 'yyyyMMdd-hhmmss'
  $zipName = "$($_.status.nodeInfo.machineID)-$($timeStamp)_logs.zip"
  $remoteZipPath = Invoke-Command -Session $_.pssession {
    $paths = get-childitem c:\k\*.log -Exclude $using:lockedFiles
    $paths += $using:lockedFiles | Foreach-Object { Copy-Item "c:\k\$_" . -Passthru }
    get-eventlog -LogName System -Source "Service Control Manager" -Message *kub* | Select-Object Index, TimeGenerated, EntryType, Message | Export-CSV -Path "$ENV:TEMP\\$($using:timeStamp)_services.csv"
    $paths += "$ENV:TEMP\\$($using:timeStamp)_services.csv"
    Get-WinEvent -LogName Microsoft-Windows-Hyper-V-Compute-Operational | Select-Object -Property TimeCreated, Id, LevelDisplayName, Message | Export-Csv -Path "$ENV:TEMP\\$($using:timeStamp)_hyper-v-compute-operational.csv"
    $paths += "$ENV:TEMP\\$($using:timeStamp)_hyper-v-compute-operational.csv"
    mkdir 'c:\k\debug' -ErrorAction Ignore
    Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/Microsoft/SDN/master/Kubernetes/windows/debug/collectlogs.ps1 -OutFile 'c:\k\debug\collectlogs.ps1'
    & 'c:\k\debug\collectlogs.ps1' | write-Host
    $netLogs = get-childitem c:\k -Recurse -Include $using:netDebugFiles
    $paths += $netLogs
    Compress-Archive -Path $paths -DestinationPath $using:zipName
    $netLogs | Foreach-Object { Remove-Item $_ } | Out-Null
    Write-Host Compressing all logs to $using:zipName
    Get-ChildItem $using:zipName
  }
  Write-Host Copying out logs
  Copy-Item -FromSession $_.pssession $remoteZipPath -Destination out/
  Write-Host "Done with $($_.status.nodeInfo.machineID)" #, closing session"
  # Remove-PSSession $_.pssession # BUG - seems to hang in a container
}
