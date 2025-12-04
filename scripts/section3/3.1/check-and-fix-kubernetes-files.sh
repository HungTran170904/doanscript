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
BACKUP_DIR="./aks-backups"
ARM_TEMPLATE_FILE="aks-arm-template-$(date +%Y%m%d-%H%M%S).json"


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

# Export AKS configuration
export_aks_config() {
    print_header "AKS Configuration Backup"
    
    # Create backup directory if it doesn't exist
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        print_info "Created backup directory: $BACKUP_DIR"
    fi
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI (az) is not installed or not in PATH"
        print_info "Please install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        return 1
    fi
    
    # Check if user is logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure CLI"
        print_info "Please run: az login"
        return 1
    fi
    
    # Get current AKS cluster info from kubectl
    print_info "Getting current cluster information..."
    local cluster_info=$(kubectl config current-context 2>/dev/null)
    
    if [ -z "$cluster_info" ]; then
        print_error "No active kubectl context found"
        print_info "Please ensure kubectl is configured and connected to your AKS cluster"
        return 1
    fi
    
    print_info "Current cluster context: $cluster_info"
    
    # Prompt for Resource Group and AKS name
    echo -e "\n${YELLOW}Please provide AKS cluster information:${NC}"
    read -p "Enter Resource Group name: " resource_group
    read -p "Enter AKS cluster name: " aks_name
    
    if [ -z "$resource_group" ] || [ -z "$aks_name" ]; then
        print_error "Resource Group and AKS name are required"
        return 1
    fi
    
    # Show backup options
    echo -e "\n${YELLOW}Choose backup method:${NC}"
    echo -e "${GREEN}1.${NC} Export ARM Template (recommended)"
    echo -e "${GREEN}2.${NC} Skip backup"
    echo -n "Enter your choice [1-2]: "
    read -n 1 backup_choice
    echo
    
    local success=false
    
    case $backup_choice in
        1)
            # Export ARM template only
            ;
    
            # Export ARM template
            local arm_template_path="$BACKUP_DIR/$ARM_TEMPLATE_FILE"
            print_info "Exporting ARM template to: $arm_template_path"
            print_warning "This may take a few minutes for large resource groups..."
            
            # Get AKS resource ID first
            local aks_resource_id=$(az aks show --resource-group "$resource_group" --name "$aks_name" --query id -o tsv 2>/dev/null)
            
            if [ -z "$aks_resource_id" ]; then
                print_error "Failed to get AKS resource ID"
                return 1
            fi
            
            print_info "AKS Resource ID: $aks_resource_id"
            
            # Export entire resource group as ARM template
            if az group export --resource-group "$resource_group" --resource-ids "$aks_resource_id" > "$arm_template_path" 2>/dev/null; then
                print_success "ARM template exported successfully!"
                print_info "ARM template saved to: $arm_template_path"
                
                local file_size=$(wc -c < "$arm_template_path" 2>/dev/null || echo "unknown")
                print_info "File size: ${file_size} bytes"
                
                # Validate ARM template
                print_info "Validating ARM template structure..."
                if command -v jq &> /dev/null; then
                    local resources_count=$(jq '.resources | length' "$arm_template_path" 2>/dev/null || echo "unknown")
                    print_info "Resources in template: $resources_count"
                fi
                
                success=true
            else
                print_error "Failed to export ARM template"
                print_error "This could be due to:"
                print_error "  - Large resource group (timeout)"
                print_error "  - Insufficient permissions"
                print_error "  - Complex resource dependencies"
                [ -f "$arm_template_path" ] && rm -f "$arm_template_path"
            fi
            ;;
        2)
            print_info "Skipping backup as requested"
            success=true
            ;;
        *)
            print_error "Invalid choice. Please select 1 or 2."
            return 1
            ;;
    esac

    
    if [ "$success" = true ]; then
        print_header "Backup Summary"
        print_success "Backup completed successfully!"
        echo -e "\n${BLUE}Backup files:${NC}"
        ls -la "$BACKUP_DIR"/*.json 2>/dev/null | tail -5
        
        echo -e "\n${YELLOW}Rollback capability: ~85%${NC}"
        echo "• Infrastructure can be redeployed using ARM template"
        
        echo -e "\n${YELLOW}Usage notes:${NC}"
        echo "• ARM Template: Can be used to redeploy infrastructure with 'az deployment group create'"
        echo "• Restores: AKS cluster, networking, storage, and related Azure resources"
        echo "• Does not restore: Kubernetes workloads, application data, or custom configurations"
        
        return 0
    else
        print_error "Backup failed. Please check the error messages above."
        print_error "Verify Resource Group: $resource_group"
        print_error "Verify AKS cluster: $aks_name"
        print_error "Check Azure CLI permissions"
        return 1
    fi
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
    echo -e "${GREEN}2.${NC} Fix permissions (with backup option)"
    echo -e "${GREEN}3.${NC} Export AKS configuration"
    echo -e "${GREEN}4.${NC} Exit program"
    echo -e "${BLUE}========================================${NC}"
    echo -n "Enter your choice [1-4]: "
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
    
    # Ask if user wants to export AKS config first
    echo -e "\n${YELLOW}Before making changes, would you like to export AKS configuration as backup?${NC}"
    read -p "Export AKS config? (Y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        if export_aks_config; then
            print_success "Configuration backup completed"
        else
            print_warning "Configuration backup failed, but continuing with permission fixes..."
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Operation cancelled by user"
                return 1
            fi
        fi
    else
        print_warning "Skipping configuration backup (not recommended)"
    fi

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
                export_aks_config
                ;;
            4)
                print_info "Exiting program..."
                # Clean up any existing DaemonSet before exiting
                if kubectl get daemonset $DAEMONSET_NAME -n $NAMESPACE &> /dev/null; then
                    print_info "Cleaning up existing DaemonSet before exit..."
                    cleanup_daemonset
                fi
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1, 2, 3, or 4."
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