# AKS etcd Encryption Management Tool
# Simplified and improved version

function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  AKS etcd Encryption Management" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Check AKS encryption status"
    Write-Host "2. Setup complete encryption (KeyVault + Identity + Key)"
    Write-Host "3. Enable encryption on AKS cluster"
    Write-Host "4. Rotate encryption key"
    Write-Host "5. Disable encryption"
    Write-Host "6. Exit"
    Write-Host ""
}

function Select-Subscription {
    $subscriptions = az account list --output json | ConvertFrom-Json
    
    if ($subscriptions.Count -eq 0) {
        Write-Host "No subscription found. Please login with 'az login'" -ForegroundColor Red
        return $null
    }
    
    Write-Host "`nAvailable Subscriptions:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $subscriptions.Count; $i++) {
        Write-Host "$($i + 1). $($subscriptions[$i].name)"
    }
    
    $choice = Read-Host "`nSelect subscription"
    $selected = $subscriptions[$choice - 1]
    
    if ($selected) {
        az account set --subscription $selected.id
        Write-Host "Using: $($selected.name)" -ForegroundColor Green
    }
    
    return $selected
}

function Select-ResourceGroup {
    param([string]$Prompt = "Select resource group")
    
    $rgs = az group list --output json | ConvertFrom-Json
    
    if ($rgs.Count -eq 0) {
        Write-Host "No resource groups found" -ForegroundColor Red
        return $null
    }
    
    Write-Host "`nResource Groups:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $rgs.Count; $i++) {
        Write-Host "$($i + 1). $($rgs[$i].name) [$($rgs[$i].location)]"
    }
    
    $choice = Read-Host "`n$Prompt"
    return $rgs[$choice - 1]
}

function Check-AKSEncryption {
    Write-Host "`n=== Check Encryption Status ===" -ForegroundColor Yellow
    
    if (-not (Select-Subscription)) { return }
    
    $rg = Select-ResourceGroup
    if (-not $rg) { return }
    
    $clusters = az aks list --resource-group $rg.name --output json | ConvertFrom-Json
    
    if ($clusters.Count -eq 0) {
        Write-Host "No AKS clusters found" -ForegroundColor Red
        Read-Host "`nPress Enter"
        return
    }
    
    Write-Host "`nAKS Clusters:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $clusters.Count; $i++) {
        Write-Host "$($i + 1). $($clusters[$i].name)"
    }
    
    $choice = Read-Host "`nSelect cluster"
    $cluster = $clusters[$choice - 1]
    
    if (-not $cluster) {
        Write-Host "Invalid selection" -ForegroundColor Red
        Read-Host "`nPress Enter"
        return
    }
    
    Write-Host "`nChecking: $($cluster.name)..." -ForegroundColor Yellow
    
    $kms = az aks show --name $cluster.name --resource-group $rg.name `
        --query "securityProfile.azureKeyVaultKms" --output json | ConvertFrom-Json
    
    Write-Host "`n--- Results ---" -ForegroundColor Cyan
    Write-Host "Cluster: $($cluster.name)"
    Write-Host "Resource Group: $($rg.name)"
    
    if ($kms -and $kms.enabled) {
        Write-Host "`nStatus: " -NoNewline
        Write-Host "ENABLED" -ForegroundColor Green
        Write-Host "Key ID: $($kms.keyId)"
        Write-Host "Network Access: $($kms.keyVaultNetworkAccess)"
        Write-Host "Key Vault ID: $($kms.keyVaultResourceId)"
    } else {
        Write-Host "`nStatus: " -NoNewline
        Write-Host "NOT ENABLED" -ForegroundColor Red
    }
    
    Read-Host "`nPress Enter"
}

function Setup-CompleteEncryption {
    Write-Host "`n=== Complete Encryption Setup ===" -ForegroundColor Yellow
    Write-Host "This will create: Key Vault, Managed Identity, and Key" -ForegroundColor Cyan
    
    if (-not (Select-Subscription)) { return }
    
    $rg = Select-ResourceGroup
    if (-not $rg) { return }
    
    # Input names
    Write-Host "`n--- Configuration ---" -ForegroundColor Cyan
    $kvName = Read-Host "Key Vault name (unique, lowercase, max 24 chars)"
    $identityName = Read-Host "Managed Identity name (e.g., aks-kms-identity)"
    $keyName = Read-Host "Encryption key name (e.g., etcd-encryption-key)"
    
    if ([string]::IsNullOrWhiteSpace($kvName) -or 
        [string]::IsNullOrWhiteSpace($identityName) -or 
        [string]::IsNullOrWhiteSpace($keyName)) {
        Write-Host "`nAll fields are required" -ForegroundColor Red
        Read-Host "Press Enter"
        return
    }
    
    Write-Host "`n--- Creating Resources ---" -ForegroundColor Yellow
    
    # 1. Create Key Vault with RBAC
    Write-Host "`n1. Creating Key Vault: $kvName..." -ForegroundColor Cyan
    $kvResult = az keyvault create `
        --name $kvName `
        --resource-group $rg.name `
        --location $rg.location `
        --enable-rbac-authorization true `
        --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create Key Vault:" -ForegroundColor Red
        Write-Host $kvResult
        Read-Host "`nPress Enter"
        return
    }
    
    $kv = $kvResult | ConvertFrom-Json
    Write-Host "   Created: $($kv.name)" -ForegroundColor Green
    
    # 2. Create Managed Identity
    Write-Host "`n2. Creating Managed Identity: $identityName..." -ForegroundColor Cyan
    $idResult = az identity create `
        --name $identityName `
        --resource-group $rg.name `
        --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create identity:" -ForegroundColor Red
        Write-Host $idResult
        Read-Host "`nPress Enter"
        return
    }
    
    $identity = $idResult | ConvertFrom-Json
    Write-Host "   Created: $($identity.name)" -ForegroundColor Green
    Write-Host "   Principal ID: $($identity.principalId)" -ForegroundColor Gray
    
    # 3. Assign Key Vault Crypto Officer to current user (to create keys)
    Write-Host "`n3. Assigning permissions to create keys..." -ForegroundColor Cyan
    $currentUserId = az ad signed-in-user show --query id -o tsv
    
    az role assignment create `
        --role "Key Vault Crypto Officer" `
        --assignee-object-id $currentUserId `
        --assignee-principal-type "User" `
        --scope $kv.id `
        --output none 2>&1 | Out-Null
    
    Write-Host "   Assigned to current user" -ForegroundColor Green
    
    # Wait for RBAC propagation
    Write-Host "`n4. Waiting for permissions to propagate (30 seconds)..." -ForegroundColor Cyan
    Start-Sleep -Seconds 30
    
    # 4. Create Key
    Write-Host "`n5. Creating encryption key: $keyName..." -ForegroundColor Cyan
    $keyResult = az keyvault key create `
        --vault-name $kvName `
        --name $keyName `
        --kty RSA `
        --size 2048 `
        --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create key:" -ForegroundColor Red
        Write-Host $keyResult
        Write-Host "`nTry running this command manually after a few minutes:" -ForegroundColor Yellow
        Write-Host "az keyvault key create --vault-name $kvName --name $keyName --kty RSA --size 2048" -ForegroundColor Cyan
        Read-Host "`nPress Enter"
        return
    }
    
    $key = $keyResult | ConvertFrom-Json
    Write-Host "   Created: $($key.name)" -ForegroundColor Green
    Write-Host "   Key ID: $($key.key.kid)" -ForegroundColor Gray
    
    # 5. Assign Key Vault Crypto User to Managed Identity
    Write-Host "`n6. Assigning 'Key Vault Crypto User' to Identity..." -ForegroundColor Cyan
    az role assignment create `
        --role "Key Vault Crypto User" `
        --assignee-object-id $identity.principalId `
        --assignee-principal-type "ServicePrincipal" `
        --scope $kv.id `
        --output none 2>&1 | Out-Null
    
    Write-Host "   Assigned successfully" -ForegroundColor Green
    
    # Summary
    Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
    Write-Host "Key Vault: $kvName"
    Write-Host "Identity: $identityName"
    Write-Host "Key: $keyName"
    Write-Host "Key ID: $($key.key.kid)"
    Write-Host "`nYou can now enable encryption on your AKS cluster (Option 3)" -ForegroundColor Cyan
    
    Read-Host "`nPress Enter"
}

function Enable-AKSEncryption {
    Write-Host "`n=== Enable AKS Encryption ===" -ForegroundColor Yellow
    
    if (-not (Select-Subscription)) { return }
    
    $rg = Select-ResourceGroup
    if (-not $rg) { return }
    
    # Select AKS Cluster
    $clusters = az aks list --resource-group $rg.name --output json | ConvertFrom-Json
    
    if ($clusters.Count -eq 0) {
        Write-Host "No AKS clusters found" -ForegroundColor Red
        Read-Host "`nPress Enter"
        return
    }
    
    Write-Host "`nAKS Clusters:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $clusters.Count; $i++) {
        Write-Host "$($i + 1). $($clusters[$i].name)"
    }
    
    $choice = Read-Host "`nSelect cluster"
    $cluster = $clusters[$choice - 1]
    if (-not $cluster) { return }
    
    # Check current identity type
    $clusterDetails = az aks show --name $cluster.name --resource-group $rg.name --output json | ConvertFrom-Json
    $identityType = $clusterDetails.identity.type
    
    Write-Host "`nCluster identity type: $identityType" -ForegroundColor Cyan
    
    # Show warning for SystemAssigned identity
    if ($identityType -eq "SystemAssigned") {
        Write-Host "`nIMPORTANT: This cluster uses SystemAssigned identity." -ForegroundColor Yellow
        Write-Host "KMS requires UserAssigned identity. Migration will be performed automatically." -ForegroundColor Yellow
        Write-Host "Migration time: 10-15 minutes (cluster will remain operational)" -ForegroundColor Gray
    }
    
    # Select Key Vault
    $kvs = az keyvault list --resource-group $rg.name --output json | ConvertFrom-Json
    
    if ($kvs.Count -eq 0) {
        Write-Host "`nNo Key Vaults found. Run option 2 first." -ForegroundColor Red
        Read-Host "Press Enter"
        return
    }
    
    Write-Host "`nKey Vaults:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $kvs.Count; $i++) {
        Write-Host "$($i + 1). $($kvs[$i].name)"
    }
    
    $choice = Read-Host "`nSelect Key Vault"
    $kv = $kvs[$choice - 1]
    if (-not $kv) { return }
    
    # Get Key Vault resource ID
    $kvResourceId = az keyvault show --name $kv.name --resource-group $rg.name --query id -o tsv
    
    # List keys in Key Vault
    $keys = az keyvault key list --vault-name $kv.name --output json | ConvertFrom-Json
    
    if ($keys.Count -eq 0) {
        Write-Host "`nNo keys found in Key Vault. Run option 2 first." -ForegroundColor Red
        Read-Host "Press Enter"
        return
    }
    
    Write-Host "`nKeys:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $keys.Count; $i++) {
        Write-Host "$($i + 1). $($keys[$i].name)"
    }
    
    $choice = Read-Host "`nSelect key"
    $keyName = $keys[$choice - 1].name
    if (-not $keyName) { return }
    
    # Get full key ID
    $keyId = az keyvault key show --vault-name $kv.name --name $keyName --query 'key.kid' -o tsv
    
    # Select Managed Identity
    $identities = az identity list --resource-group $rg.name --output json | ConvertFrom-Json
    
    if ($identities.Count -eq 0) {
        Write-Host "`nNo Managed Identities found. Run option 2 first." -ForegroundColor Red
        Read-Host "Press Enter"
        return
    }
    
    Write-Host "`nManaged Identities:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $identities.Count; $i++) {
        Write-Host "$($i + 1). $($identities[$i].name)"
    }
    
    $choice = Read-Host "`nSelect identity"
    $identity = $identities[$choice - 1]
    if (-not $identity) { return }
    
    # Verify and assign Key Vault permissions to identity
    Write-Host "`nVerifying Key Vault permissions..." -ForegroundColor Cyan
    
    $existingRole = az role assignment list `
        --assignee $identity.principalId `
        --scope $kvResourceId `
        --role "Key Vault Crypto User" `
        --query "[0].id" -o tsv 2>$null
    
    if ([string]::IsNullOrWhiteSpace($existingRole)) {
        Write-Host "Assigning 'Key Vault Crypto User' role..." -ForegroundColor Yellow
        az role assignment create `
            --role "Key Vault Crypto User" `
            --assignee-object-id $identity.principalId `
            --assignee-principal-type "ServicePrincipal" `
            --scope $kvResourceId `
            --output none 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   Permissions assigned successfully" -ForegroundColor Green
            Write-Host "   Waiting 15 seconds for propagation..." -ForegroundColor Gray
            Start-Sleep -Seconds 15
        } else {
            Write-Host "   Warning: Failed to assign permissions" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   Identity already has required permissions" -ForegroundColor Green
    }
    
    # Confirm
    Write-Host "`n--- Configuration ---" -ForegroundColor Yellow
    Write-Host "Cluster: $($cluster.name)"
    Write-Host "Identity Type: $identityType"
    Write-Host "Key Vault: $($kv.name)"
    Write-Host "Key: $keyName"
    Write-Host "Managed Identity: $($identity.name)"
    
    $confirm = Read-Host "`nEnable encryption? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Cancelled" -ForegroundColor Red
        Read-Host "`nPress Enter"
        return
    }
    
    Write-Host "`nEnabling encryption (this may take 5-10 minutes)..." -ForegroundColor Cyan
    Write-Host "Started: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    
    # Build command based on identity type
    if ($identityType -eq "None") {
        # Cluster has no identity - need to enable managed identity first
        Write-Host "Enabling managed identity and KMS on cluster..." -ForegroundColor Yellow
        
        $result = az aks update `
            --name $cluster.name `
            --resource-group $rg.name `
            --enable-managed-identity `
            --assign-identity $identity.id `
            --enable-azure-keyvault-kms `
            --azure-keyvault-kms-key-vault-network-access "Public" `
            --azure-keyvault-kms-key-id $keyId `
            --output json 2>&1
            
    } elseif ($identityType -eq "SystemAssigned") {
        # Cluster has system-assigned identity - need to migrate to user-assigned
        Write-Host "WARNING: Cluster uses SystemAssigned identity." -ForegroundColor Yellow
        Write-Host "For KMS, you need to migrate to UserAssigned identity." -ForegroundColor Yellow
        Write-Host "`nThis requires 2 steps:" -ForegroundColor Cyan
        Write-Host "1. Migrate cluster to use UserAssigned identity (this will preserve cluster state)"
        Write-Host "2. Enable KMS encryption"
        Write-Host ""
        
        $migrate = Read-Host "Proceed with migration? (yes/no)"
        if ($migrate -ne "yes") {
            Write-Host "`nCancelled. Cannot enable KMS with SystemAssigned identity." -ForegroundColor Red
            Read-Host "Press Enter"
            return
        }
        
        Write-Host "`nStep 1: Migrating to UserAssigned identity..." -ForegroundColor Yellow
        Write-Host "This may take 10-15 minutes..." -ForegroundColor Gray
        
        # First, migrate from SystemAssigned to UserAssigned
        $migrateResult = az aks update `
            --name $cluster.name `
            --resource-group $rg.name `
            --enable-managed-identity `
            --assign-identity $identity.id `
            --yes `
            --output json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "`nFailed to migrate identity:" -ForegroundColor Red
            Write-Host $migrateResult
            Read-Host "`nPress Enter"
            return
        }
        
        Write-Host "Identity migration completed!" -ForegroundColor Green
        Write-Host "`nStep 2: Enabling KMS encryption..." -ForegroundColor Yellow
        Write-Host "This may take 5-10 minutes..." -ForegroundColor Gray
        
        # Now enable KMS
        $result = az aks update `
            --name $cluster.name `
            --resource-group $rg.name `
            --enable-azure-keyvault-kms `
            --azure-keyvault-kms-key-vault-network-access "Public" `
            --azure-keyvault-kms-key-id $keyId `
            --output json 2>&1
            
    } else {
        # Cluster already has user-assigned identity
        Write-Host "Enabling KMS with UserAssigned identity..." -ForegroundColor Yellow
        
        $result = az aks update `
            --name $cluster.name `
            --resource-group $rg.name `
            --enable-azure-keyvault-kms `
            --azure-keyvault-kms-key-vault-network-access "Public" `
            --azure-keyvault-kms-key-id $keyId `
            --output json 2>&1
    }
    
    Write-Host "Completed: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n=== SUCCESS ===" -ForegroundColor Green
        Write-Host "Encryption enabled on cluster: $($cluster.name)"
        Write-Host "`nIMPORTANT: Update all secrets to encrypt them:" -ForegroundColor Yellow
        Write-Host "kubectl get secrets --all-namespaces -o json | kubectl replace -f -" -ForegroundColor Cyan
        Write-Host "`nNOTE: This command must be run from a machine with kubectl access to the cluster" -ForegroundColor Gray
    } else {
        Write-Host "`n=== FAILED ===" -ForegroundColor Red
        Write-Host $result
        Write-Host "`nTroubleshooting tips:" -ForegroundColor Yellow
        Write-Host "1. Verify the identity has 'Key Vault Crypto User' role on the Key Vault"
        Write-Host "2. Ensure the cluster has network access to the Key Vault"
        Write-Host "3. Check if AKS preview features are enabled in your subscription"
    }
    
    Read-Host "`nPress Enter"
}

function Rotate-EncryptionKey {
    Write-Host "`n=== Rotate Encryption Key ===" -ForegroundColor Yellow
    
    if (-not (Select-Subscription)) { return }
    
    $rg = Select-ResourceGroup
    if (-not $rg) { return }
    
    # Select AKS Cluster
    $clusters = az aks list --resource-group $rg.name --output json | ConvertFrom-Json
    if ($clusters.Count -eq 0) {
        Write-Host "No clusters found" -ForegroundColor Red
        Read-Host "`nPress Enter"
        return
    }
    
    Write-Host "`nAKS Clusters:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $clusters.Count; $i++) {
        Write-Host "$($i + 1). $($clusters[$i].name)"
    }
    
    $choice = Read-Host "`nSelect cluster"
    $cluster = $clusters[$choice - 1]
    if (-not $cluster) { return }
    
    # Get current KMS config
    $kms = az aks show --name $cluster.name --resource-group $rg.name `
        --query "securityProfile.azureKeyVaultKms" --output json | ConvertFrom-Json
    
    if (-not $kms -or -not $kms.enabled) {
        Write-Host "`nEncryption not enabled on this cluster" -ForegroundColor Red
        Read-Host "Press Enter"
        return
    }
    
    Write-Host "`nCurrent key: $($kms.keyId)" -ForegroundColor Cyan
    
    # Get Key Vault name from keyId
    $kvName = ($kms.keyId -split '/')[2] -replace '\.vault\.azure\.net', ''
    
    # List keys
    $keys = az keyvault key list --vault-name $kvName --output json | ConvertFrom-Json
    
    Write-Host "`nAvailable keys:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $keys.Count; $i++) {
        Write-Host "$($i + 1). $($keys[$i].name)"
    }
    Write-Host "$($keys.Count + 1). Create new key"
    
    $choice = Read-Host "`nSelect key or create new"
    
    if ($choice -eq ($keys.Count + 1)) {
        $newKeyName = Read-Host "Enter new key name"
        
        Write-Host "Creating key: $newKeyName..." -ForegroundColor Cyan
        $keyResult = az keyvault key create `
            --vault-name $kvName `
            --name $newKeyName `
            --kty RSA `
            --size 2048 `
            --output json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to create key" -ForegroundColor Red
            Read-Host "`nPress Enter"
            return
        }
        
        $keyData = $keyResult | ConvertFrom-Json
        $newKeyId = $keyData.key.kid
    } else {
        $selectedKey = $keys[$choice - 1]
        $newKeyId = az keyvault key show --vault-name $kvName --name $selectedKey.name --query 'key.kid' -o tsv
    }
    
    Write-Host "`nRotating to new key..." -ForegroundColor Yellow
    Write-Host "New key: $newKeyId" -ForegroundColor Cyan
    
    $result = az aks update `
        --name $cluster.name `
        --resource-group $rg.name `
        --enable-azure-keyvault-kms `
        --azure-keyvault-kms-key-vault-network-access "Public" `
        --azure-keyvault-kms-key-id $newKeyId `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n=== SUCCESS ===" -ForegroundColor Green
        Write-Host "Key rotated successfully"
        Write-Host "`nIMPORTANT: Update all secrets:" -ForegroundColor Yellow
        Write-Host "kubectl get secrets --all-namespaces -o json | kubectl replace -f -" -ForegroundColor Cyan
        Write-Host "`nNOTE: Keep both old and new keys valid until next rotation!" -ForegroundColor Yellow
    } else {
        Write-Host "`nFailed to rotate key:" -ForegroundColor Red
        Write-Host $result
    }
    
    Read-Host "`nPress Enter"
}

function Disable-AKSEncryption {
    Write-Host "`n=== Disable Encryption ===" -ForegroundColor Yellow
    Write-Host "WARNING: This will disable KMS encryption" -ForegroundColor Red
    
    if (-not (Select-Subscription)) { return }
    
    $rg = Select-ResourceGroup
    if (-not $rg) { return }
    
    $clusters = az aks list --resource-group $rg.name --output json | ConvertFrom-Json
    if ($clusters.Count -eq 0) {
        Write-Host "No clusters found" -ForegroundColor Red
        Read-Host "`nPress Enter"
        return
    }
    
    Write-Host "`nAKS Clusters:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $clusters.Count; $i++) {
        Write-Host "$($i + 1). $($clusters[$i].name)"
    }
    
    $choice = Read-Host "`nSelect cluster"
    $cluster = $clusters[$choice - 1]
    if (-not $cluster) { return }
    
    $confirm = Read-Host "`nDisable encryption on $($cluster.name)? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Cancelled" -ForegroundColor Red
        Read-Host "`nPress Enter"
        return
    }
    
    Write-Host "`nDisabling encryption..." -ForegroundColor Yellow
    
    $result = az aks update `
        --name $cluster.name `
        --resource-group $rg.name `
        --disable-azure-keyvault-kms `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n=== SUCCESS ===" -ForegroundColor Green
        Write-Host "Encryption disabled"
        Write-Host "`nUpdate all secrets:" -ForegroundColor Yellow
        Write-Host "kubectl get secrets --all-namespaces -o json | kubectl replace -f -" -ForegroundColor Cyan
        Write-Host "`nWARNING: Do NOT delete or expire the keys yet!" -ForegroundColor Red
    } else {
        Write-Host "`nFailed to disable:" -ForegroundColor Red
        Write-Host $result
    }
    
    Read-Host "`nPress Enter"
}

# Main Loop
do {
    Show-Menu
    $choice = Read-Host "Select option (1-6)"
    
    switch ($choice) {
        '1' { Check-AKSEncryption }
        '2' { Setup-CompleteEncryption }
        '3' { Enable-AKSEncryption }
        '4' { Rotate-EncryptionKey }
        '5' { Disable-AKSEncryption }
        '6' { 
            Write-Host "`nGoodbye!" -ForegroundColor Green
            exit 
        }
        default {
            Write-Host "`nInvalid choice" -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($choice -ne '6')