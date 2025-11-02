$nodeName = "aks-default-42248339-vmss000000"
$image = "mcr.microsoft.com/cbl-mariner/busybox:2.0"

$commands = @'
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
    update_param anonymous-auth false
fi

if [ "$(extract_param authorization-mode)" != "Webhook" ]; then
    update_param authorization-mode Webhook
fi

if [ -z "$(extract_param client-ca-file)" ]; then
    update_param client-ca-file /etc/kubernetes/certs/ca.crt
fi

if [ "$(extract_param read-only-port)" != "0" ]; then
    update_param read-only-port 0
fi

if [ -z "$(extract_param streaming-connection-idle-timeout)" ]; then
    update_param streaming-connection-idle-timeout 4h
fi

if [ "$(extract_param make-iptables-util-chains)" != "true" ]; then
    update_param make-iptables-util-chains true
fi

if [ "$(extract_param event-qps)" -le 5 ]; then
    update_param event-qps 5
fi

if [ "$(extract_param rotate-certificates)" != "true" ]; then
    update_param rotate-certificates true
fi

if [ "$(extract_param rotate-server-certificates)" != "true" ]; then
    update_param rotate-server-certificates true
fi

systemctl restart kubelet
'@

# Encode commands to base64
$encodedCommands = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($commands))

# Get all node names
$nodesStr = kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | Out-String
$nodeList = $nodesStr.Trim() -split '\s+'

# Execute commands inside nodes
foreach ($nodeName in $nodeList) {
    kubectl debug node/$nodeName -it --image=$image -- chroot /host /bin/sh -c "echo $encodedCommands | base64 -d | sh"
}
