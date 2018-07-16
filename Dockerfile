FROM mcr.microsoft.com/powershell
RUN mkdir /opt/k
WORKDIR /opt/k
RUN curl -L https://dl.k8s.io/v1.11.0/kubernetes-client-linux-amd64.tar.gz | tar xvzf - ; mv kubernetes/client/bin/kubectl . ; rm -rf kubernetes
ADD logslurp.ps1 /opt/k
SHELL [ "pwsh" ]
CMD logslurp.ps1
