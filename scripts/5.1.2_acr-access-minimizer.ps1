<#
  ACR Access Minimizer - RBAC helper for Azure Container Registry (PowerShell)
  Goal: Minimize user access to Azure Container Registry (ACR)
  Features:
    1) List who has what role on an ACR
    2) Grant AcrPull to an assignee (AKS MI/SP objectId or appId/objectId)
    3) Delete a role assignment on ACR
    4) Exit
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ===== Console helpers =====
function Info($m)  { Write-Host $m -ForegroundColor Cyan }
function Ok($m)    { Write-Host $m -ForegroundColor Green }
function Warn($m)  { Write-Host $m -ForegroundColor Yellow }
function Err($m)   { Write-Host $m -ForegroundColor Red }
function Title($m) { Write-Host $m -ForegroundColor Magenta }
function Pause-Enter { Read-Host "Press Enter to continue..." | Out-Null }

# ===== Pre-check =====
function Test-AzCli {
  if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Err "Azure CLI (az) is not installed. Please install and run 'az login'."
    exit 1
  }
}

# ===== Subscription =====
function Select-Subscription {
  $subscriptions = az account list --output json | ConvertFrom-Json
  
  if ($subscriptions.Count -eq 0) {
    Err "No subscription found. Please login with 'az login'"
    return $null
  }
  
  if ($subscriptions.Count -eq 1) {
    Info "Using subscription: $($subscriptions[0].name)"
    az account set --subscription $subscriptions[0].id | Out-Null
    return $subscriptions[0]
  }
  
  Write-Host ""
  Info "Available Subscriptions:"
  for ($i = 0; $i -lt $subscriptions.Count; $i++) {
    Write-Host "  $($i + 1). $($subscriptions[$i].name) [$($subscriptions[$i].id)]"
  }
  
  do {
    Write-Host ""
    $choice = Read-Host "Select subscription (1-$($subscriptions.Count))"
    $index = [int]$choice - 1
  } while ($index -lt 0 -or $index -ge $subscriptions.Count)
  
  $selected = $subscriptions[$index]
  
  if ($selected) {
    az account set --subscription $selected.id | Out-Null
    Ok "Using subscription: $($selected.name)"
  }
  
  return $selected
}

function Get-SubscriptionId {
  param([string]$SubscriptionId)
  if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
    try {
      $sub = az account show -o json | Out-String | ConvertFrom-Json
      if (-not $sub -or -not $sub.id) { throw "No default subscription. Run 'az login' then 'az account set --subscription <id>'." }
      return $sub.id
    } catch {
      Err "Cannot get current subscription: $($_.Exception.Message)"
      throw
    }
  }
  return $SubscriptionId
}

# ===== ACR ID =====
function Get-AcrId {
  param(
    [Parameter(Mandatory=$true)][string]$AcrName,
    [string]$SubscriptionId
  )
  $subId = Get-SubscriptionId -SubscriptionId $SubscriptionId
  try {
    $acr = az acr show -n $AcrName --subscription $subId -o json | Out-String | ConvertFrom-Json
    if (-not $acr -or -not $acr.id) { throw "ACR '$AcrName' does not exist or you have no access." }
    return $acr.id
  } catch {
    Err "Failed to get ACR ID. Check ACR name or your access. Detail: $($_.Exception.Message)"
    throw
  }
}

# ===== Resource Group & ACR selection helpers (interactive) =====
function Select-ResourceGroup {
  param([string]$Prompt = "Select resource group")

  $rgs = az group list --output json | ConvertFrom-Json

  if (-not $rgs -or $rgs.Count -eq 0) {
    Warn "No resource groups found"
    return $null
  }

  Write-Host "`nResource Groups:" -ForegroundColor Cyan
  for ($i = 0; $i -lt $rgs.Count; $i++) {
    Write-Host "  $($i + 1). $($rgs[$i].name) [$($rgs[$i].location)]"
  }

  do {
    $choice = Read-Host "`n$Prompt (enter number)"
    $ok = [int]::TryParse($choice,[ref]$null)
  } while (-not $ok)

  return $rgs[[int]$choice - 1]
}

function Select-Acr {
  param([string]$ResourceGroupName)

  if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
    Warn "Resource group is required to list ACRs"
    return $null
  }

  $acrs = az acr list --resource-group $ResourceGroupName --output json | ConvertFrom-Json

  if (-not $acrs -or $acrs.Count -eq 0) {
    Warn "No ACRs found in resource group: $ResourceGroupName"
    return $null
  }

  Write-Host "`nAvailable ACRs:" -ForegroundColor Cyan
  for ($i = 0; $i -lt $acrs.Count; $i++) {
    Write-Host "  $($i + 1). $($acrs[$i].name) [$($acrs[$i].loginServer)]"
  }

  do {
    $choice = Read-Host "Select ACR (enter number)"
    $ok = [int]::TryParse($choice,[ref]$null)
  } while (-not $ok)

  return $acrs[[int]$choice - 1]
}

function Select-Role {
  param([string]$Prompt = "Select role")
  
  $commonRoles = @(
    @{name="AcrPull"; description="Pull images from registry"},
    @{name="AcrPush"; description="Push and pull images"},
    @{name="Reader"; description="View all resources"},
    @{name="Contributor"; description="Manage all resources"},
    @{name="Owner"; description="Full access to all resources"}
  )
  
  Write-Host "`nCommon ACR Roles:" -ForegroundColor Cyan
  for ($i = 0; $i -lt $commonRoles.Count; $i++) {
    Write-Host "  $($i + 1). $($commonRoles[$i].name) - $($commonRoles[$i].description)"
  }
  Write-Host "  $($commonRoles.Count + 1). Enter custom role name"
  
  do {
    $choice = Read-Host "`n$Prompt (enter number)"
    $ok = [int]::TryParse($choice,[ref]$null)
  } while (-not $ok -or [int]$choice -lt 1 -or [int]$choice -gt ($commonRoles.Count + 1))
  
  $index = [int]$choice - 1
  if ($index -eq $commonRoles.Count) {
    return Read-Host "Enter custom role name"
  } else {
    return $commonRoles[$index].name
  }
}

function Select-PrincipalFromAcrRoles {
  param(
    [string]$AcrName,
    [string]$SubscriptionId
  )
  
  try {
    $acrId = Get-AcrId -AcrName $AcrName -SubscriptionId $SubscriptionId
    $json = az role assignment list --subscription $SubscriptionId --scope $acrId -o json | Out-String
    $items = $json | ConvertFrom-Json
    
    if (-not $items -or $items.Count -eq 0) {
      Warn "No role assignments found on ACR '$AcrName'"
      return $null
    }
    
    Write-Host "`nCurrent role assignments on ACR '$AcrName':" -ForegroundColor Cyan
    for ($i = 0; $i -lt $items.Count; $i++) {
      $principal = if ($items[$i].principalName) { $items[$i].principalName } else { "(Unknown)" }
      Write-Host "  $($i + 1). $principal [$($items[$i].principalId)] - $($items[$i].roleDefinitionName)"
    }
    
    do {
      $choice = Read-Host "`nSelect assignee (enter number)"
      $ok = [int]::TryParse($choice,[ref]$null)
    } while (-not $ok -or [int]$choice -lt 1 -or [int]$choice -gt $items.Count)
    
    return $items[[int]$choice - 1]
  } catch {
    Warn "Failed to get role assignments: $($_.Exception.Message)"
    return $null
  }
}

# ===== Header =====
function Print-Header {
  Clear-Host
  Title "============================================================="
  Title "   MINIMIZE USER ACCESS to Azure Container Registry (ACR)"
  Title "============================================================="
  Info  "- Principle: least privilege."
  Info  "- Recommendation: AKS/Pods need only 'AcrPull'; CI/CD needs 'AcrPush'."
  Write-Host ""
}

# ===== 1) List role assignments =====
function List-AcrRoles {
  try {
    Write-Host ""
    Info "Select ACR to list role assignments:"
    
    $sub = Select-Subscription
    if (-not $sub) { Warn "No subscription selected. Cancel."; return }
    $rg = Select-ResourceGroup
    if (-not $rg) { Warn "No resource group selected. Cancel."; return }
    $acrObj = Select-Acr -ResourceGroupName $rg.name
    if (-not $acrObj) { Warn "No ACR selected. Cancel."; return }
    
    $acrName = $acrObj.name
    $subId = $sub.id
    $acrId = Get-AcrId -AcrName $acrName -SubscriptionId $subId

    Info "`nRole assignments on ACR '$acrName':"
    $json = az role assignment list --subscription $subId --scope $acrId -o json | Out-String
    $items = $json | ConvertFrom-Json


    if (-not $items) { Warn "No role assignment found on this scope."; return }

    $items | Select-Object `
      @{n="PrincipalName";e={$_.principalName}}, `
      @{n="PrincipalId";e={$_.principalId}}, `
      @{n="PrincipalType";e={$_.principalType}}, `
      @{n="Role";e={$_.roleDefinitionName}}, `
      @{n="Scope";e={$_.scope}} `
      | Format-Table -AutoSize
  } catch {
    Err "List role assignments failed: $($_.Exception.Message)"
  }
}

# ===== 2) Grant AcrPull to an assignee =====
function Grant-AcrAssignee {
  try {
    Write-Host ""
    Info "Select ACR to grant role assignment:"
    
    # Get ACR and subscription info first through selection
    $sub = Select-Subscription
    if (-not $sub) { Warn "No subscription selected. Cancel."; return }
    $rg = Select-ResourceGroup
    if (-not $rg) { Warn "No resource group selected. Cancel."; return }
    $acrObj = Select-Acr -ResourceGroupName $rg.name
    if (-not $acrObj) { Warn "No ACR selected. Cancel."; return }
    
    $acrName = $acrObj.name
    $subId = $sub.id
    
    # Now ask for assignee ID (this is the only manual input needed)
    Write-Host ""
    $assigneeId = Read-Host "Enter ASSIGNEE ID (objectId of MI/SP or appId/objectId)"
    
    # If no assignee ID provided, we can't proceed
    if ([string]::IsNullOrWhiteSpace($assigneeId)) {
      Warn "ASSIGNEE_ID is required. Cancel."
      return
    }

    # Select role to grant
    $roleName = Select-Role -Prompt "Select role to grant"
    if ([string]::IsNullOrWhiteSpace($roleName)) {
      Warn "No role selected. Cancel."
      return
    }

    $acrId = Get-AcrId -AcrName $acrName -SubscriptionId $subId

    Info "Granting '$roleName' to '$assigneeId' on ACR '$acrName' ..."
    $granted = $false

    try {
      az role assignment create `
        --assignee-object-id $assigneeId `
        --role $roleName `
        --scope $acrId `
        --subscription $subId | Out-Null
      $granted = $true
      Ok "Granted $roleName via --assignee-object-id."
    } catch {
      try {
        az role assignment create `
          --assignee $assigneeId `
          --role $roleName `
          --scope $acrId `
          --subscription $subId | Out-Null
        $granted = $true
        Ok "Granted $roleName via --assignee."
      } catch {
        Err "Grant failed. Check the ID you provided and your permission."
      }
    }

    if (-not $granted) { Warn "Could not grant $roleName to '$assigneeId'." }
  } catch {
    Err "Error while granting AcrPull: $($_.Exception.Message)"
  }
}

# ===== 3) Delete a role assignment =====
function Remove-AcrAssignment {
  try {
    Write-Host ""
    Info "Select ACR to manage role assignments:"
    Write-Host ""

    # Get ACR first through selection menu
    $sub = Select-Subscription
    if (-not $sub) { Warn "No subscription selected. Cancel."; return }
    $rg = Select-ResourceGroup
    if (-not $rg) { Warn "No resource group selected. Cancel."; return }
    $acrObj = Select-Acr -ResourceGroupName $rg.name
    if (-not $acrObj) { Warn "No ACR selected. Cancel."; return }
    
    $acrName = $acrObj.name
    $subId = $sub.id

    # Select from existing role assignments
    $selectedAssignment = Select-PrincipalFromAcrRoles -AcrName $acrName -SubscriptionId $subId
    if (-not $selectedAssignment) {
      Warn "No role assignment selected. Cancel."
      return
    }

    $assigneeOid = $selectedAssignment.principalId
    $roleName = $selectedAssignment.roleDefinitionName
    $principalName = if ($selectedAssignment.principalName) { $selectedAssignment.principalName } else { "(Unknown)" }
    
    Write-Host ""
    Info "Selected assignment to delete:"
    Write-Host "  Principal: $principalName ($assigneeOid)"
    Write-Host "  Role: $roleName"
    Write-Host "  ACR: $acrName"
    Write-Host ""
    
    $confirm = Read-Host "Are you sure you want to delete this role assignment? (yes/no)"
    if ($confirm -ne "yes") {
      Warn "Operation cancelled."
      return
    }

    $acrId = Get-AcrId -AcrName $acrName -SubscriptionId $subId

    Info "Deleting role '$roleName' for '$principalName' on ACR '$acrName' ..."
    az role assignment delete `
      --assignee-object-id $assigneeOid `
      --role $roleName `
      --scope $acrId `
      --subscription $subId | Out-Null

    Ok "Role assignment deleted."
  } catch {
    Err "Delete failed. Check your inputs or permission. Detail: $($_.Exception.Message)"
  }
}

# ===== Menu =====
function Main-Menu {
  while ($true) {
    Print-Header
    Write-Host "Choose an option:"
    Write-Host "  1) List who has what role on ACR"
    Write-Host "  2) Grant role to assignee (interactive selection)"
    Write-Host "  3) Delete role assignment (interactive selection)"
    Write-Host "  4) Exit"
    Write-Host ""

    $opt = Read-Host "Your choice (1/2/3/4)"
    switch ($opt) {
      '1' { List-AcrRoles; Write-Host ""; Pause-Enter }
      '2' { Grant-AcrAssignee; Write-Host ""; Pause-Enter }
      '3' { Remove-AcrAssignment; Write-Host ""; Pause-Enter }
      '4' { Ok "Goodbye!"; break }
      default { Warn "Invalid choice."; Pause-Enter }
    }
  }
}

# ===== Run =====
Test-AzCli
try {
  $null = az account show -o json | Out-String | ConvertFrom-Json
} catch {
  Warn "You are not logged in. Opening device login..."
  az login --use-device-code | Out-Null
}
Main-Menu
