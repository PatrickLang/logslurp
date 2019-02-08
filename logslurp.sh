#!/bin/bash

if [[ -z $1 ]] || [[ -z $2 ]]; then
    echo "Usage: $0 adminuser@master adminuser@windowsnode"
    echo
    echo "Note: SSH agent forwarding must be enabled for your current session to avoid passwords"
    exit 1
fi

read -r -d '' remoteCommand <<'EOF'
    $lockedFiles = "kubelet.err.log", "kubelet.log", "kubeproxy.log", "kubeproxy.err.log"; 
    $netDebugFiles = "network.txt", "endpoint.txt", "policy.txt", "ip.txt", "ports.txt", "routes.txt", "vfpOutput.txt";
    $timeStamp = get-date -format 'yyyyMMdd-hhmmss';
    $zipName = "$(hostname)-$($timeStamp)_logs.zip";

    $paths = get-childitem c:\k\*.log -Exclude $lockedFiles;
    $paths += $lockedFiles | Foreach-Object { Copy-Item "c:\k\$_" . -Passthru };
    $scm = Get-WinEvent -FilterHashtable @{logname='System';ProviderName='Service Control Manager'} | Where-Object { $_.Message -Like "*docker*" -or $_.Message -Like "*kub*" } | Select-Object -Property TimeCreated, Id, LevelDisplayName, Message;
    $reboots = Get-WinEvent -FilterHashtable @{logname='System'; id=1074,1076,2004,6005,6006,6008} | Select-Object -Property TimeCreated, Id, LevelDisplayName, Message;
    $crashes = Get-WinEvent -FilterHashtable @{logname='Application'; ProviderName='Windows Error Reporting' } | Select-Object -Property TimeCreated, Id, LevelDisplayName, Message;
    $scm + $reboots + $crashes | Sort-Object TimeCreated | Export-CSV -Path "$ENV:TEMP\\$($timeStamp)_services.csv";
    $paths += "$ENV:TEMP\\$($timeStamp)_services.csv";
    Get-WinEvent -LogName Microsoft-Windows-Hyper-V-Compute-Operational | Select-Object -Property TimeCreated, Id, LevelDisplayName, Message | Sort-Object TimeCreated | Export-Csv -Path "$ENV:TEMP\\$($timeStamp)_hyper-v-compute-operational.csv";
    $paths += "$ENV:TEMP\\$($timeStamp)_hyper-v-compute-operational.csv";
    get-eventlog -LogName Application -Source Docker | Select-Object Index, TimeGenerated, EntryType, Message | Sort-Object Index | Export-CSV -Path "$ENV:TEMP\\$($timeStamp)_docker.csv";
    $paths += "$ENV:TEMP\\$($timeStamp)_docker.csv";
    Get-CimInstance win32_pagefileusage | Format-List * | Out-File -Append "$ENV:TEMP\\$($timeStamp)_pagefile.txt";
    Get-CimInstance win32_computersystem | Format-List AutomaticManagedPagefile | Out-File -Append "$ENV:TEMP\\$($timeStamp)_pagefile.txt";
    $paths += "$ENV:TEMP\\$($timeStamp)_pagefile.txt";
    mkdir 'c:\k\debug' -ErrorAction Ignore | Out-Null;
    Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/Microsoft/SDN/master/Kubernetes/windows/debug/collectlogs.ps1 -OutFile 'c:\k\debug\collectlogs.ps1';
    & 'c:\k\debug\collectlogs.ps1' | write-Host;
    $netLogs = get-childitem c:\k -Recurse -Include $netDebugFiles;
    $paths += $netLogs;
    Compress-Archive -Path $paths -DestinationPath $zipName;
    $netLogs | Foreach-Object { Remove-Item $_ } | Out-Null;
    Write-Host Compressing all logs to $zipName;
    (Get-ChildItem $zipName).FullName;
EOF

remoteEncoded=$(echo $remoteCommand | base64 -w 0)

ssh -t -o "ProxyCommand ssh -W %h:%p $1" $2 powershell.exe "-nologo -command \" Invoke-Expression -Command ([System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String('$remoteEncoded')))  \" "
