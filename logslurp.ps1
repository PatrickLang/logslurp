
$lockedFiles = "kubelet.err.log", "kubelet.log", "kubeproxy.log", "kubeproxy.err.log"

$cred = Get-Credential -Message "Please enter an admin username & password to connect to the Windows nodes"
$nodes = ./kubectl get node -o json | ConvertFrom-Json
$nodes.items | Where-Object { $_.metadata.labels.'beta.kubernetes.io/os' -eq 'windows' } | foreach-object {
  Add-Member -InputObject $_ -MemberType NoteProperty -Name "pssession" -Value (New-PSSession -ComputerName $_.status.nodeInfo.machineID -Credential $cred -UseSSL -Authentication basic)
  Write-Host Connected to $_.status.nodeInfo.machineID
  # Write-Host Logs:
  $zipName = "$($_.status.nodeInfo.machineID)-$(get-date -format 'yyyyMMdd-hhmmss')_logs.zip"
  $remoteZipPath = Invoke-Command -Session $_.pssession { 
    $paths = get-childitem c:\k\*.log -Exclude $using:lockedFiles
    $paths += $using:lockedFiles | Foreach-Object { Copy-Item "c:\k\$_" . -Passthru }
    Compress-Archive -Path $paths -DestinationPath $using:zipName
    Get-ChildItem $using:zipName
  } 
  Copy-Item -FromSession $_.pssession $remoteZipPath -Destination out/
}
