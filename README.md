# logslurp

This will find all the Windows Kubernetes nodes, and attempt to gather all the logs from `c:\k\*.log` into a single zip file. 

Prerequisites:

- Windows nodes must have PowerShell remoting enabled, and allow basic auth with SSL. [This script](https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1) makes it easy

## Build it

```
docker build -t logslurp . 
```

## Run it

```
docker run -i -t -v ~/.kube/config:/root/.kube/config -v $PWD:/opt/k/out logslurp
```

![running it on a 2 node cluster](logslurp.gif)
