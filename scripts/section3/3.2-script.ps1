param(
    [string]$EnableModify
)

$nodeName = "aks-default-42248339-vmss000000"
$image = "mcr.microsoft.com/cbl-mariner/busybox:2.0"

$checkCommands = @'
extract_param() {
    grep -oP "(?<=--$1=)[^ ]+" /etc/default/kubelet
}

if [ "$(extract_param anonymous-auth)" != "false" ]; then
    echo "CIS 3.2.1 - Non-compliant: 'anonymous-auth' is not disabled."
fi

if [ "$(extract_param authorization-mode)" != "Webhook" ]; then
    echo "CIS 3.2.2 - Non-compliant: 'authorization-mode' is not set to 'Webhook'."
fi

if [ -z "$(extract_param client-ca-file)" ]; then
    echo "CIS 3.2.3 - Non-compliant: 'client-ca-file' is not configured."
fi

if [ "$(extract_param read-only-port)" != "0" ]; then
    echo "CIS 3.2.4 - Non-compliant: 'read-only-port' is not disabled (expected 0)."
fi

if [ -z "$(extract_param streaming-connection-idle-timeout)" ]; then
    echo "CIS 3.2.5 - Non-compliant: 'streaming-connection-idle-timeout' is not set."
fi

if [ "$(extract_param make-iptables-util-chains)" != "true" ]; then
    echo "CIS 3.2.6 - Non-compliant: 'make-iptables-util-chains' is not enabled."
fi

if [ "$(extract_param event-qps)" -le 5 ]; then
    echo "CIS 3.2.7 - Non-compliant: 'event-qps' must be greater than 5."
fi

if [ "$(extract_param rotate-certificates)" != "true" ]; then
    echo "CIS 3.2.8 - Non-compliant: 'rotate-certificates' is not enabled."
fi

if [ "$(extract_param rotate-server-certificates)" != "true" ]; then
    echo "CIS 3.2.9 - Non-compliant: 'rotate-server-certificates' is not enabled."
fi
'@
$modifyCommands = @'
update_param() {
    param=$1
    value=$2
    file="/etc/default/kubelet"

    echo "Updating $param to $value..."

    if grep -q -- "--$param=" "$file"; then
        sed -i -E "s/(--$param=)[^ ]*/\1$value/" "$file"
    else
        sed -i -E "s|^(KUBELET_FLAGS=.*)|\1 --$param=$value|" "$file"
    fi
}

extract_param() {
    grep -oP "(?<=--$1=)[^ ]+" /etc/default/kubelet
}

if [ "$(extract_param anonymous-auth)" != "false" ]; then
    echo "CIS 3.2.1 - Non-compliant: 'anonymous-auth' is not disabled."
    update_param anonymous-auth false
fi

if [ "$(extract_param authorization-mode)" != "Webhook" ]; then
    echo "CIS 3.2.2 - Non-compliant: 'authorization-mode' is not set to 'Webhook'."
    update_param authorization-mode Webhook
fi

if [ -z "$(extract_param client-ca-file)" ]; then
    echo "CIS 3.2.3 - Non-compliant: 'client-ca-file' is not configured."
    update_param client-ca-file /etc/kubernetes/certs/ca.crt
fi

if [ "$(extract_param read-only-port)" != "0" ]; then
    echo "CIS 3.2.4 - Non-compliant: 'read-only-port' is not disabled (expected 0)."
    update_param read-only-port 0
fi

if [ -z "$(extract_param streaming-connection-idle-timeout)" ]; then
    echo "CIS 3.2.5 - Non-compliant: 'streaming-connection-idle-timeout' is not set."
    update_param streaming-connection-idle-timeout 4h
fi

if [ "$(extract_param make-iptables-util-chains)" != "true" ]; then
    echo "CIS 3.2.6 - Non-compliant: 'make-iptables-util-chains' is not enabled."
    update_param make-iptables-util-chains true
fi

if [ "$(extract_param event-qps)" -le 5 ]; then
    echo "CIS 3.2.7 - Non-compliant: 'event-qps' must be greater than 5."
    update_param event-qps 5
fi

if [ "$(extract_param rotate-certificates)" != "true" ]; then
    echo "CIS 3.2.8 - Non-compliant: 'rotate-certificates' is not enabled."
    update_param rotate-certificates true
fi

if [ "$(extract_param rotate-server-certificates)" != "true" ]; then
    echo "CIS 3.2.9 - Non-compliant: 'rotate-server-certificates' is not enabled."
    update_param rotate-server-certificates true
fi

systemctl restart kubelet
'@

Write-Host "---- Checking section 3.2: Kubelet ----" -ForegroundColor Yellow

# Encode commands to base64
if ($EnableModify -eq "true"){
    $encodedCommands = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($modifyCommands)) 
}
else {
    $encodedCommands = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($checkCommands)) 
}

# Get all node names
$nodesStr = kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | Out-String
$nodeList = $nodesStr.Trim() -split '\s+'

# Execute commands inside nodes
foreach ($nodeName in $nodeList) {
    Write-Host "- Check node $nodeName" -ForegroundColor Yellow
    kubectl debug node/$nodeName -it --image=$image -- chroot /host /bin/sh -c "echo $encodedCommands | base64 -d | sh"
}
