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

# Check file permissions only (no fixing)
check_file_only() {
    local pod=$1
    local file=$2
    local file_name=$3
    local node=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.nodeName}')

    echo -e "\n${BLUE}--- Checking $file_name on node: $node (pod: $pod) ---${NC}"

    # Check if file exists
    if ! file_exists $pod $file; then
        print_warning "File $file does not exist on this node"
        return 0
    fi

    print_info "File exists: $file"

    # Check permissions
    local current_perm=$(get_permissions $pod $file)
    echo "Current permissions: $current_perm"

    if is_permission_acceptable $current_perm; then
        print_success "Permissions are acceptable ($current_perm)"
    else
        print_error "Permissions are too permissive ($current_perm) - should be 600, 644, or 400"
        return 1
    fi

    # Check ownership
    local current_owner=$(get_ownership $pod $file)
    echo "Current ownership: $current_owner"

    if [ "$current_owner" = "$TARGET_OWNER" ]; then
        print_success "Ownership is correct ($current_owner)"
    else
        print_error "Ownership is incorrect ($current_owner) - should be $TARGET_OWNER"
        return 1
    fi

    return 0
}

# Fix file permissions and ownership
fix_file() {
    local pod=$1
    local file=$2
    local file_name=$3
    local node=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.nodeName}')

    echo -e "\n${BLUE}--- Fixing $file_name on node: $node (pod: $pod) ---${NC}"

    # Check if file exists
    if ! file_exists $pod $file; then
        print_warning "File $file does not exist on this node"
        return
    fi

    print_info "File exists: $file"

    # Check and fix permissions
    local current_perm=$(get_permissions $pod $file)
    echo "Current permissions: $current_perm"

    if is_permission_acceptable $current_perm; then
        print_success "Permissions are already acceptable ($current_perm)"
    else
        print_error "Permissions are too permissive ($current_perm)"
        fix_permissions $pod $file
        local new_perm=$(get_permissions $pod $file)
        print_success "Permissions fixed: $current_perm -> $new_perm"
    fi

    # Check and fix ownership
    local current_owner=$(get_ownership $pod $file)
    echo "Current ownership: $current_owner"

    if [ "$current_owner" = "$TARGET_OWNER" ]; then
        print_success "Ownership is already correct ($current_owner)"
    else
        print_error "Ownership is incorrect ($current_owner)"
        fix_ownership $pod $file
        local new_owner=$(get_ownership $pod $file)
        print_success "Ownership fixed: $current_owner -> $new_owner"
    fi

    # Final verification
    echo -e "\n${GREEN}Final status:${NC}"
    kubectl exec $pod -n $NAMESPACE -- ls -l $file
}

# Cleanup DaemonSet
cleanup_daemonset() {
    print_header "Cleaning up DaemonSet"
    kubectl delete daemonset $DAEMONSET_NAME -n $NAMESPACE --grace-period=10
    print_success "DaemonSet deleted"
}

# Show main menu
show_menu() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  Kubernetes File Security Manager${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}Please select an option:${NC}"
    echo -e "${GREEN}1.${NC} Check permissions only"
    echo -e "${GREEN}2.${NC} Fix permissions"
    echo -e "${GREEN}3.${NC} Exit program"
    echo -e "${BLUE}========================================${NC}"
    echo -n "Enter your choice [1-3]: "
}

# Check permissions only
check_permissions_only() {
    print_header "Checking File Permissions (Read-Only Mode)"
    echo "Target permissions: $TARGET_PERMISSION (or 644/400)"
    echo "Target ownership: $TARGET_OWNER"

    # Deploy DaemonSet
    deploy_daemonset

    # Get all pods
    pods=($(get_pods))

    if [ ${#pods[@]} -eq 0 ]; then
        print_error "No pods found. DaemonSet may not be running."
        return 1
    fi

    print_info "Found ${#pods[@]} node(s) to check"

    local issues_found=false

    # Check each file on each pod
    for pod in "${pods[@]}"; do
        print_header "Node: $(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.nodeName}')"

        # Check kubeconfig
        if ! check_file_only $pod $KUBECONFIG_PATH "kubeconfig"; then
            issues_found=true
        fi

        # Check azure.json
        if ! check_file_only $pod $AZURE_JSON_PATH "azure.json"; then
            issues_found=true
        fi
    done

    # Summary
    print_header "Check Summary"
    if [ "$issues_found" = true ]; then
        print_warning "Issues found! Some files have incorrect permissions or ownership."
        print_info "Use option 2 to fix the issues."
    else
        print_success "All file permissions and ownership are correct!"
    fi

    show_file_status
    cleanup_prompt
}

# Fix permissions
fix_permissions() {
    print_header "Fixing File Permissions"
    echo "Target permissions: $TARGET_PERMISSION"
    echo "Target ownership: $TARGET_OWNER"

    # Deploy DaemonSet
    deploy_daemonset

    # Get all pods
    pods=($(get_pods))

    if [ ${#pods[@]} -eq 0 ]; then
        print_error "No pods found. DaemonSet may not be running."
        return 1
    fi

    print_info "Found ${#pods[@]} node(s) to fix"

    # Fix each file on each pod
    for pod in "${pods[@]}"; do
        print_header "Node: $(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.nodeName}')"

        # Fix kubeconfig
        fix_file $pod $KUBECONFIG_PATH "kubeconfig"

        # Fix azure.json
        fix_file $pod $AZURE_JSON_PATH "azure.json"
    done

    # Summary
    print_header "Fix Summary"
    print_success "All fixes completed successfully!"

    show_file_status
    cleanup_prompt
}

# Show file status on all nodes
show_file_status() {
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
}

# Cleanup prompt
cleanup_prompt() {
    echo -e "\n"
    read -p "Do you want to cleanup the DaemonSet? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_daemonset
    else
        print_info "DaemonSet kept running. Delete manually with: kubectl delete daemonset $DAEMONSET_NAME -n $NAMESPACE"
    fi
}

# Main execution
main() {
    print_header "Kubernetes File Security Manager"

    while true; do
        show_menu
        read -n 1 choice
        echo

        case $choice in
            1)
                check_permissions_only
                ;;
            2)
                fix_permissions
                ;;
            3)
                print_info "Exiting program..."
                # Clean up any existing DaemonSet before exiting
                if kubectl get daemonset $DAEMONSET_NAME -n $NAMESPACE &> /dev/null; then
                    print_info "Cleaning up existing DaemonSet before exit..."
                    cleanup_daemonset
                fi
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1, 2, or 3."
                ;;
        esac

        # Ask if user wants to continue
        echo -e "\n"
        read -p "Do you want to return to main menu? (Y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            print_info "Exiting program..."
            exit 0
        fi
    done
}

# Run main function
main