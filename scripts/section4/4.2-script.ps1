param(
    [string]$EnableModify
)

# List of Kubernetes resource types that contain pod templates
$workloadTypes = @(
    "deployment",
    "statefulset",
    "daemonset",
    "replicaset",
    "job",
    "cronjob",
    "pod"
)

function Get-AllWorkloadPods {
    $allItems = @()

    foreach ($type in $workloadTypes) {
        try {
            $json = kubectl get $type --all-namespaces -o json | ConvertFrom-Json
        } catch {
            continue
        }

        if ($null -ne $json.items) {
            foreach ($item in $json.items) {
                if ($type -eq "pod"){ $podSpec = $item.spec }
                else { $podSpec = $item.spec.template.spec }
                
                $allItems += [PSCustomObject]@{
                    Kind = $type
                    Name = $item.metadata.name
                    Namespace = $item.metadata.namespace
                    PodSpec = $podSpec
                }
            }
        }
    }

    return $allItems
}

function ScanPodSpecs {
    $results = @()
    $workloads = Get-AllWorkloadPods

    foreach ($w in $workloads) {
        $containers = @()
        $podSpec = $w.PodSpec
        $SectionViolations = @()

        if ($null -ne $podSpec.containers) { 
            $containers += $podSpec.containers 
        }
        if ($null -ne $podSpec.initContainers) { 
            $containers += $podSpec.initContainers 
        }
        if ($null -ne $podSpec.ephemeralContainers) { 
            $containers += $podSpec.ephemeralContainers 
        }

        if ($podSpec.hostPID -eq $true){
            $SectionViolations += "4.2.2"
        }
        if ($podSpec.hostIPC -eq $true){
            $SectionViolations += "4.2.3"
        }
        if ($podSpec.hostNetwork -eq $true){
            $SectionViolations += "4.2.4"
        }

        foreach($c in $containers) {
            if ($null -eq $c.securityContext) { continue }

            if ($c.securityContext.privileged -eq $true -and -not ($SectionViolations -contains "4.2.1")) {
                $SectionViolations += "4.2.1"
            }
            if ($c.securityContext.allowPrivilegeEscalation -eq $true -and -not ($SectionViolations -contains "4.2.5")) {
                $SectionViolations += "4.2.5"
            }
        }

        if($SectionViolations.Count -ne 0) {
            $results += [PSCustomObject]@{
                Kind     = $w.Kind
                Namespace = $w.Namespace
                Resource = $w.Name
                SectionViolations = $SectionViolations -join ", "
            }
        }
    }

    return $results
}

function ModifyPodSpecs(){
    param(
        $ResourceEntries
    )

    foreach($resourceEntry in $ResourceEntries) {
        $parts = $resourceEntry -split "/"
        if ($parts.Count -ne 3) {
            Write-Host "Skipping invalid Resource entry: $resourceEntry" -ForegroundColor Red
            continue
        }
        $type = $parts[0]
        $namespace = $parts[1]
        $name = $parts[2]

        $workloadJson = kubectl get $type $name -n $namespace -o json | ConvertFrom-Json
        if ($type -eq "pod"){ $podSpec = $workloadJson.spec }
        else { $podSpec = $workloadJson.spec.template.spec }

        $containers = @()
        if ($null -ne $podSpec.containers) { 
            $containers += $podSpec.containers 
        }
        if ($null -ne $podSpec.initContainers) { 
            $containers += $podSpec.initContainers 
        }
        if ($null -ne $podSpec.ephemeralContainers) { 
            $containers += $podSpec.ephemeralContainers 
        }

        if ($podSpec.hostPID -eq $true){
            $podSpec.hostPID = $false
        }
        if ($podSpec.hostIPC -eq $true){
            $podSpec.hostIPC = $false
        }
        if ($podSpec.hostNetwork -eq $true){
            $podSpec.hostNetwork = $false
        }

        foreach($c in $containers) {
            if ($null -eq $c.securityContext) { continue }

            if ($c.securityContext.privileged -eq $true) {
                $c.securityContext.privileged = $false
            }
            if ($c.securityContext.allowPrivilegeEscalation -eq $true) {
                $c.securityContext.allowPrivilegeEscalation = $false
            }
        }

        $workloadJson | ConvertTo-Json -Depth 10 | kubectl apply -f -
    }
}

# --- Main Execution ---
Write-Host "----Checking section 4.2: Pod Security Standards----" -ForegroundColor Yellow
Write-Host "Below are list of checked CIS rules in section 4.2:"
Write-Host "----Checking section 4.2.1: Minimize the admission of privileged containers----" -ForegroundColor Yellow
Write-Host "----Checking section 4.2.2: Minimize the admission of containers wishing to share the host process ID namespace ----" -ForegroundColor Yellow
Write-Host "----Checking section 4.2.3: Minimize the admission of containers wishing to share the host IPC namespace ----" -ForegroundColor Yellow
Write-Host "----Checking section 4.2.4: Minimize the admission of containers wishing to share the host network namespace ----" -ForegroundColor Yellow
Write-Host "----Checking section 4.2.5: Minimize the admission of containers with allowPrivilegeEscalation ----" -ForegroundColor Yellow

$scanResults = ScanPodSpecs

if ($scanResults.Count -eq 0) {
    Write-Host "No violations found." -ForegroundColor Green
} else {
    Write-Host "Violations detected:" -ForegroundColor Yellow
    $scanResults | Format-Table -AutoSize

    if ($EnableModify -eq "true") {
        Write-Host "Enter Resource entries to fix pod security violations (format: resource-type/namespace/name, separated by commas):" -ForegroundColor Cyan
        $resourceEntriesStr = Read-Host
        $resourceEntries = $resourceEntriesStr -split "," | ForEach-Object { $_.Trim() }
        ModifyPodSpecs -ResourceEntries $resourceEntries
    }
}