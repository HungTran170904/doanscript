set -e


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


DAEMONSET_FILE="file-check-daemonset.yaml"
DAEMONSET_NAME="file-check"
NAMESPACE="default"
KUBECONFIG_PATH="/host/var/lib/kubelet/kubeconfig"
AZURE_JSON_PATH="/host/etc/kubernetes/azure.json"
TARGET_PERMISSION="600"
TARGET_OWNER="root:root"


print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}


# Deploy DaemonSet
deploy_daemonset() {
    print_header "Deploying DaemonSet"

    if kubectl get daemonset $DAEMONSET_NAME -n $NAMESPACE &> /dev/null; then
        print_info "DaemonSet already exists, deleting old one..."
        kubectl delete daemonset $DAEMONSET_NAME -n $NAMESPACE --grace-period=0 --force &> /dev/null || true

        print_info "Waiting for old pods to be terminated (30 seconds)..."
        sleep 30

        local remaining_pods=$(kubectl get pods -n $NAMESPACE -l app=file-check --no-headers 2>/dev/null | wc -l)
        if [ $remaining_pods -gt 0 ]; then
            print_warning "Still found $remaining_pods old pod(s), waiting additional 15 seconds..."
            sleep 15
        fi

        print_success "Old DaemonSet cleanup completed"
    fi

    print_info "Creating DaemonSet..."
    kubectl apply -f $DAEMONSET_FILE -n $NAMESPACE

    print_info "Waiting for DaemonSet pods to be ready..."
    kubectl rollout status daemonset/$DAEMONSET_NAME -n $NAMESPACE --timeout=120s

    sleep 3
    print_success "DaemonSet deployed successfully"
}

# Get all DaemonSet pods
get_pods() {
    kubectl get pods -n $NAMESPACE -l app=file-check -o jsonpath='{.items[*].metadata.name}'
}

# Check if file exists in pod
file_exists() {
    local pod=$1
    local file=$2
    kubectl exec $pod -n $NAMESPACE -- test -f $file 2>/dev/null
    return $?
}

# Get file permissions
get_permissions() {
    local pod=$1
    local file=$2
    kubectl exec $pod -n $NAMESPACE -- stat -c %a $file 2>/dev/null
}

# Get file ownership
get_ownership() {
    local pod=$1
    local file=$2
    kubectl exec $pod -n $NAMESPACE -- stat -c "%U:%G" $file 2>/dev/null
}

# Check if permissions are acceptable (644 or 600)
is_permission_acceptable() {
    local perm=$1
    [ "$perm" = "644" ] || [ "$perm" = "600" ] || [ "$perm" = "400" ]
}

# Fix permissions
fix_permissions() {
    local pod=$1
    local file=$2
    print_warning "Fixing permissions for $file to $TARGET_PERMISSION"
    kubectl exec $pod -n $NAMESPACE -- chmod $TARGET_PERMISSION $file
}

# Fix ownership
fix_ownership() {
    local pod=$1
    local file=$2
    print_warning "Fixing ownership for $file to $TARGET_OWNER"
    kubectl exec $pod -n $NAMESPACE -- chown $TARGET_OWNER $file
}

# Check and fix a single file on a pod
check_and_fix_file() {
    local pod=$1
    local file=$2
    local file_name=$3
    local node=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.nodeName}')

    echo -e "\n${BLUE}--- Checking $file_name on node: $node (pod: $pod) ---${NC}"

    # Check if file exists
    if ! file_exists $pod $file; then
        print_warning "File $file does not exist on this node"
        return
    fi

    print_info "File exists: $file"

    # Check permissions
    local current_perm=$(get_permissions $pod $file)
    echo "Current permissions: $current_perm"

    if is_permission_acceptable $current_perm; then
        print_success "Permissions are acceptable ($current_perm)"
        local perm_fixed=false
    else
        print_error "Permissions are too permissive ($current_perm)"
        fix_permissions $pod $file
        local new_perm=$(get_permissions $pod $file)
        print_success "Permissions fixed: $current_perm -> $new_perm"
        local perm_fixed=true
    fi

    # Check ownership
    local current_owner=$(get_ownership $pod $file)
    echo "Current ownership: $current_owner"

    if [ "$current_owner" = "$TARGET_OWNER" ]; then
        print_success "Ownership is correct ($current_owner)"
        local owner_fixed=false
    else
        print_error "Ownership is incorrect ($current_owner)"
        fix_ownership $pod $file
        local new_owner=$(get_ownership $pod $file)
        print_success "Ownership fixed: $current_owner -> $new_owner"
        local owner_fixed=true
    fi

    # Final verification
    if [ "$perm_fixed" = true ] || [ "$owner_fixed" = true ]; then
        echo -e "\n${GREEN}Final status:${NC}"
        kubectl exec $pod -n $NAMESPACE -- ls -l $file
    fi
}

# Cleanup DaemonSet
cleanup_daemonset() {
    print_header "Cleaning up DaemonSet"
    kubectl delete daemonset $DAEMONSET_NAME -n $NAMESPACE --grace-period=10
    print_success "DaemonSet deleted"
}

# Main execution
main() {
    print_header "Kubernetes File Security Checker and Fixer"
    echo "Target permissions: $TARGET_PERMISSION"
    echo "Target ownership: $TARGET_OWNER"

    # Deploy DaemonSet
    deploy_daemonset

    # Get all pods
    print_header "Checking Files on All Nodes"
    pods=($(get_pods))

    if [ ${#pods[@]} -eq 0 ]; then
        print_error "No pods found. DaemonSet may not be running."
        exit 1
    fi

    print_info "Found ${#pods[@]} node(s) to check" 

    # Check each file on each pod
    for pod in "${pods[@]}"; do
        print_header "Node: $(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.nodeName}')"

        # Check kubeconfig
        check_and_fix_file $pod $KUBECONFIG_PATH "kubeconfig"

        # Check azure.json
        check_and_fix_file $pod $AZURE_JSON_PATH "azure.json"
    done

    # Summary
    print_header "Summary"
    print_success "All checks and fixes completed successfully!"

    echo -e "\nFinal file status on all nodes:"
    for pod in "${pods[@]}"; do
        local node=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.nodeName}')
        echo -e "\n${BLUE}Node: $node${NC}"

        if file_exists $pod $KUBECONFIG_PATH; then
            echo "kubeconfig:"
            kubectl exec $pod -n $NAMESPACE -- ls -l $KUBECONFIG_PATH 2>/dev/null || echo "  Error reading file"
        fi

        if file_exists $pod $AZURE_JSON_PATH; then
            echo "azure.json:"
            kubectl exec $pod -n $NAMESPACE -- ls -l $AZURE_JSON_PATH 2>/dev/null || echo "  Error reading file"
        fi
    done

    # Cleanup
    echo -e "\n"
    read -p "Do you want to cleanup the DaemonSet? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_daemonset
    else
        print_info "DaemonSet kept running. Delete manually with: kubectl delete daemonset $DAEMONSET_NAME -n $NAMESPACE"
    fi
}

# Run main function
main