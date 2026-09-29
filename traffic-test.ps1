param(
    [int]$DurationSeconds = 30
)

$results = @()
$endTime = (Get-Date).AddSeconds($DurationSeconds)

Write-Host "Starting traffic test for $DurationSeconds seconds..."
Write-Host "Target: http://dummy-service/version"
Write-Host ""

while ((Get-Date) -lt $endTime) {

    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

    try {
        $start = Get-Date

        $output = kubectl exec traffic-client -- curl -sS --max-time 2 `
            http://dummy-service/version 2>&1

        $duration = ((Get-Date) - $start).TotalMilliseconds

        $json = $output | ConvertFrom-Json

        $results += [PSCustomObject]@{
            Timestamp = $timestamp
            Status    = 200
            Error     = ""
            Version   = $json.version
            Instance  = $json.instance
            LatencyMs = [math]::Round($duration, 0)
        }

        Write-Host "$timestamp | 200 | $($json.version) | $($json.instance)"

    }
    catch {

        $results += [PSCustomObject]@{
            Timestamp = $timestamp
            Status    = 000
            Error     = $_.Exception.Message
            Version   = ""
            Instance  = ""
            LatencyMs = ""
        }

        Write-Host "$timestamp | ERROR | $($_.Exception.Message)"
    }

    Start-Sleep -Seconds 1
}

$results | Export-Csv traffic-results.csv -NoTypeInformation

Write-Host ""
Write-Host "========== SUMMARY =========="

$total = $results.Count
$success = ($results | Where-Object {$_.Status -eq 200}).Count
$failed = $total - $success

Write-Host "Total requests : $total"
Write-Host "Successful     : $success"
Write-Host "Failed         : $failed"

Write-Host ""
Write-Host "Versions observed:"
$results |
    Where-Object {$_.Version -ne ""} |
    Group-Object Version |
    Select-Object Name, Count |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Instances observed:"
$results |
    Where-Object {$_.Instance -ne ""} |
    Group-Object Instance |
    Select-Object Name, Count |
    Format-Table -AutoSize