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
    $acrName = Read-Host "Enter ACR_NAME"
    if ([string]::IsNullOrWhiteSpace($acrName)) { Warn "ACR_NAME is empty. Cancel."; return }

    $subId = Get-SubscriptionId
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
function Grant-AcrPullToAssignee {
  try {
    Write-Host ""
    $assigneeId = Read-Host "Enter ASSIGNEE ID (objectId of MI/SP or appId/objectId)"
    $acrName    = Read-Host "Enter ACR_NAME"

    if ([string]::IsNullOrWhiteSpace($assigneeId) -or [string]::IsNullOrWhiteSpace($acrName)) {
      Warn "Missing info. Need both ASSIGNEE_ID and ACR_NAME."
      return
    }

    $subId = Get-SubscriptionId
    $acrId = Get-AcrId -AcrName $acrName -SubscriptionId $subId

    Info "Granting 'AcrPull' to '$assigneeId' on ACR '$acrName' ..."
    $granted = $false

    try {
      az role assignment create `
        --assignee-object-id $assigneeId `
        --role AcrPull `
        --scope $acrId `
        --subscription $subId | Out-Null
      $granted = $true
      Ok "Granted AcrPull via --assignee-object-id."
    } catch {
      try {
        az role assignment create `
          --assignee $assigneeId `
          --role AcrPull `
          --scope $acrId `
          --subscription $subId | Out-Null
        $granted = $true
        Ok "Granted AcrPull via --assignee."
      } catch {
        Err "Grant failed. Check the ID you provided and your permission."
      }
    }

    if (-not $granted) { Warn "Could not grant AcrPull to '$assigneeId'." }
  } catch {
    Err "Error while granting AcrPull: $($_.Exception.Message)"
  }
}

# ===== 3) Delete a role assignment =====
function Remove-AcrAssignment {
  try {
    Write-Host ""
    Info "You need 3 inputs (see Option 1 to list):"
    Write-Host " - Assignee Object ID (PrincipalId)"
    Write-Host " - Role name (e.g., AcrPull, AcrPush, Reader, Contributor, Owner)"
    Write-Host " - ACR_NAME"
    Write-Host ""

    $assigneeOid = Read-Host "Enter Assignee Object ID"
    $roleName    = Read-Host "Enter Role name"
    $acrName     = Read-Host "Enter ACR_NAME"

    if ([string]::IsNullOrWhiteSpace($assigneeOid) -or
        [string]::IsNullOrWhiteSpace($roleName)   -or
        [string]::IsNullOrWhiteSpace($acrName)) {
      Warn "Missing info. Cancel."
      return
    }

    $subId = Get-SubscriptionId
    $acrId = Get-AcrId -AcrName $acrName -SubscriptionId $subId

    Info "Deleting role '$roleName' for '$assigneeOid' on ACR '$acrName' ..."
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
    Write-Host "  2) Grant AcrPull to AKS Node Pool SP / Managed Identity"
    Write-Host "  3) Delete role assignment"
    Write-Host "  4) Exit"
    Write-Host ""

    $opt = Read-Host "Your choice (1/2/3/4)"
    switch ($opt) {
      '1' { List-AcrRoles; Write-Host ""; Pause-Enter }
      '2' { Grant-AcrPullToAssignee; Write-Host ""; Pause-Enter }
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
