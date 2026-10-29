<# :
@echo off
setlocal
set "CLI_ARG=%~1"
set "SCRIPT_PATH=%~f0"
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "[ScriptBlock]::Create((Get-Content -LiteralPath $env:SCRIPT_PATH -Raw)).Invoke()"
pause
exit /b %ERRORLEVEL%
#>

$ErrorActionPreference = "Stop"

function Test-ReservedName {
    param([string]$Name)
    if ([string]::IsNullOrEmpty($Name)) { return $false }
    $stem = $Name.Split('.')[0]
    if ([string]::IsNullOrEmpty($stem)) { return $false }
    return ($stem -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$')
}

function Get-SafeDisplayName {
    param([string]$Name)
    return ($Name -replace '[\x00-\x1F\x7F]', '?')
}

# Target directory is the folder where this .bat file resides
$targetDir = Split-Path -Parent $env:SCRIPT_PATH
if (-not $targetDir -or -not (Test-Path -LiteralPath $targetDir)) {
    Write-Host "Error: Could not determine the script directory." -ForegroundColor Red
    return
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "           UNDO LAST ACTION (Polyglot Wrapper)            " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Target Folder: $targetDir" -ForegroundColor White
Write-Host ""

# Determine target log file: CLI argument / drag-and-drop or latest log in folder
$logPath = $null
if (-not [string]::IsNullOrWhiteSpace($env:CLI_ARG)) {
    $potentialPath = $env:CLI_ARG.Trim('"', ' ')
    if (Test-Path -LiteralPath $potentialPath -PathType Leaf) {
        $logPath = (Get-Item -LiteralPath $potentialPath).FullName
    } elseif (Test-Path -LiteralPath (Join-Path -Path $targetDir -ChildPath $potentialPath) -PathType Leaf) {
        $logPath = (Get-Item -LiteralPath (Join-Path -Path $targetDir -ChildPath $potentialPath)).FullName
    } else {
        Write-Host "Error: Specified log file does not exist: $potentialPath" -ForegroundColor Red
        Write-Host ""
        return
    }
} else {
    # Auto-discover the latest active organize or rename log in target directory
    $activeLogs = @(Get-ChildItem -LiteralPath $targetDir -File | Where-Object {
        $_.Name -match '^(organize_log_|rename_log_)\d{8}_\d{6}(_\d+)?\.txt$'
    } | Sort-Object -Property LastWriteTime -Descending)

    if ($activeLogs.Count -gt 0) {
        $logPath = $activeLogs[0].FullName
    }
}

if (-not $logPath) {
    Write-Host "No active action logs (organize_log_*.txt or rename_log_*.txt) found in target folder." -ForegroundColor DarkYellow
    Write-Host "Tip: Drag and drop a specific log file onto this script to undo it." -ForegroundColor Gray
    Write-Host ""
    return
}

$logFileName = [System.IO.Path]::GetFileName($logPath)
Write-Host "Selected Log: $logFileName" -ForegroundColor Yellow

# Read and parse log file
$rawLines = @()
try {
    $rawLines = [System.IO.File]::ReadAllLines($logPath, [System.Text.Encoding]::UTF8)
} catch {
    Write-Host "Error: Failed to read log file '$logFileName': $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    return
}

if ($rawLines.Count -eq 0) {
    Write-Host "Error: Log file is empty: $logFileName" -ForegroundColor Red
    Write-Host ""
    return
}

# Determine log type
$isOrganizeLog = $false
$isRenameLog = $false

if ($rawLines[0] -match '^organize_by_type\.bat') {
    $isOrganizeLog = $true
} elseif ($rawLines[0] -match '^rename_screenshots\.bat') {
    $isRenameLog = $true
} else {
    # Fallback heuristic by checking header tokens
    if ($rawLines -contains "[MOVED]") {
        $isOrganizeLog = $true
    } elseif ($rawLines -contains "[RENAMED]") {
        $isRenameLog = $true
    } else {
        Write-Host "Error: Unrecognized log file format in '$logFileName'." -ForegroundColor Red
        Write-Host ""
        return
    }
}

$actionHeader = if ($isOrganizeLog) { "[MOVED]" } else { "[RENAMED]" }
$inActionBlock = $false
$actionLines = [System.Collections.Generic.List[string]]::new()

foreach ($line in $rawLines) {
    $trimmed = $line.Trim()
    if ($trimmed -eq $actionHeader) {
        $inActionBlock = $true
        continue
    }
    if ($inActionBlock) {
        if ($trimmed.StartsWith("[") -and $trimmed.EndsWith("]")) {
            break
        }
        if (-not [string]::IsNullOrWhiteSpace($trimmed) -and $trimmed -ne "(none)") {
            $actionLines.Add($trimmed)
        }
    }
}

if ($actionLines.Count -eq 0) {
    Write-Host "No recorded file operations found to undo in '$logFileName'." -ForegroundColor DarkYellow
    Write-Host ""
    return
}

# Parse original and destination pairs
# Format: <OriginalPath> -> <CurrentPath>
# Under Win32 specifications, '>' is strictly forbidden in file and directory paths,
# guaranteeing that splitting on " -> " is delimiter-safe and immune to path collisions.
$rawPlan = [System.Collections.Generic.List[PSCustomObject]]::new()
$delimiter = " -> "

foreach ($entry in $actionLines) {
    $idx = $entry.IndexOf($delimiter)
    if ($idx -lt 0) {
        continue
    }
    $origPath = $entry.Substring(0, $idx).Trim()
    $currPath = $entry.Substring($idx + $delimiter.Length).Trim()

    if (-not [string]::IsNullOrEmpty($origPath) -and -not [string]::IsNullOrEmpty($currPath)) {
        $rawPlan.Add([PSCustomObject]@{
            OriginalPath = $origPath
            CurrentPath  = $currPath
        })
    }
}

if ($rawPlan.Count -eq 0) {
    Write-Host "No valid file mappings found to undo in '$logFileName'." -ForegroundColor DarkYellow
    Write-Host ""
    return
}

# Reverse order (LIFO) to ensure safe undo and avoid path collision cascades
$planLIFO = [System.Collections.Generic.List[PSCustomObject]]::new()
for ($i = $rawPlan.Count - 1; $i -ge 0; $i--) {
    $planLIFO.Add($rawPlan[$i])
}

# Pre-validate restoration plan
$executablePlan = [System.Collections.Generic.List[PSCustomObject]]::new()
$skippedMissing = [System.Collections.Generic.List[PSCustomObject]]::new()
$skippedCollisions = [System.Collections.Generic.List[PSCustomObject]]::new()
$skippedReparsePoints = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($item in $planLIFO) {
    # 1. Verify that current file exists
    if (-not (Test-Path -LiteralPath $item.CurrentPath -PathType Leaf)) {
        $skippedMissing.Add($item)
        continue
    }

    # 2. Check for reparse point (symlink/junction) guard
    $currItemObj = Get-Item -LiteralPath $item.CurrentPath -Force
    if ($currItemObj.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        $skippedReparsePoints.Add($item)
        continue
    }

    # 3. Collision guard: verify that the destination (original location) is not occupied
    if (Test-Path -LiteralPath $item.OriginalPath) {
        $skippedCollisions.Add($item)
        continue
    }

    $executablePlan.Add($item)
}

# Display Preview
Write-Host "Operation Type: $(if ($isOrganizeLog) { 'Undo Organize (Move files back to source)' } else { 'Undo Rename (Restore original names)' })" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "Planned Restorations ($($executablePlan.Count)):" -ForegroundColor White

$previewLimit = 30
$displayCount = [Math]::Min($executablePlan.Count, $previewLimit)

for ($i = 0; $i -lt $displayCount; $i++) {
    $item = $executablePlan[$i]
    $currName = Get-SafeDisplayName ([System.IO.Path]::GetFileName($item.CurrentPath))
    $origName = Get-SafeDisplayName ([System.IO.Path]::GetFileName($item.OriginalPath))
    if ($isOrganizeLog) {
        $currRelative = Split-Path -Leaf (Split-Path -Parent $item.CurrentPath)
        Write-Host "  [$currRelative/$currName] -> $origName" -ForegroundColor Gray
    } else {
        Write-Host "  $currName -> $origName" -ForegroundColor Gray
    }
}

if ($executablePlan.Count -gt $previewLimit) {
    $remaining = $executablePlan.Count - $previewLimit
    Write-Host "  ... and $remaining more file(s)" -ForegroundColor DarkGray
}

Write-Host ""

# Report skipped items
if ($skippedMissing.Count -gt 0) {
    Write-Host "SKIPPED (File not found at current location):" -ForegroundColor DarkYellow
    foreach ($s in $skippedMissing) {
        Write-Host "  - $(Get-SafeDisplayName ([System.IO.Path]::GetFileName($s.CurrentPath)))" -ForegroundColor DarkYellow
    }
    Write-Host ""
}
if ($skippedCollisions.Count -gt 0) {
    Write-Host "SKIPPED (Original location already occupied, collision blocked):" -ForegroundColor DarkYellow
    foreach ($s in $skippedCollisions) {
        Write-Host "  - $(Get-SafeDisplayName ([System.IO.Path]::GetFileName($s.OriginalPath)))" -ForegroundColor DarkYellow
    }
    Write-Host ""
}
if ($skippedReparsePoints.Count -gt 0) {
    Write-Host "SKIPPED (Symbolic link or junction, left in place):" -ForegroundColor DarkYellow
    foreach ($s in $skippedReparsePoints) {
        Write-Host "  - $(Get-SafeDisplayName ([System.IO.Path]::GetFileName($s.CurrentPath)))" -ForegroundColor DarkYellow
    }
    Write-Host ""
}

Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "Planned: $($executablePlan.Count) | Missing: $($skippedMissing.Count) | Collisions: $($skippedCollisions.Count) | ReparsePoints: $($skippedReparsePoints.Count)" -ForegroundColor White
Write-Host "----------------------------------------------------------`n" -ForegroundColor DarkGray

if ($executablePlan.Count -eq 0) {
    Write-Host "No files can be restored. All items were missing or blocked." -ForegroundColor DarkYellow
    Write-Host ""
    return
}

# Prompt confirmation
$response = Read-Host "Do you want to proceed with undoing these $($executablePlan.Count) action(s)? [y/N]"

if ($null -eq $response -or $response.Trim() -notmatch '^(y|yes)$') {
    Write-Host "`nOperation cancelled by user. No files were modified." -ForegroundColor Red
    Write-Host ""
    return
}

# Execute undo restorations
$restoredCount = 0
$restoredItems = [System.Collections.Generic.List[PSCustomObject]]::new()
$errors = [System.Collections.Generic.List[string]]::new()

Write-Host "`nRestoring files..." -ForegroundColor Gray

foreach ($item in $executablePlan) {
    try {
        $destParent = Split-Path -Parent $item.OriginalPath
        if (-not (Test-Path -LiteralPath $destParent -PathType Container)) {
            [System.IO.Directory]::CreateDirectory($destParent) | Out-Null
        }
        Move-Item -LiteralPath $item.CurrentPath -Destination $item.OriginalPath -ErrorAction Stop
        $restoredCount++
        $restoredItems.Add($item)
    } catch {
        $currDisp = Get-SafeDisplayName ([System.IO.Path]::GetFileName($item.CurrentPath))
        $origDisp = Get-SafeDisplayName ([System.IO.Path]::GetFileName($item.OriginalPath))
        $errors.Add("Failed to restore '$currDisp' to '$origDisp': $($_.Exception.Message)")
    }
}

# If organize undo: prune known empty category directories
$cleanedDirs = [System.Collections.Generic.List[string]]::new()
if ($isOrganizeLog) {
    $knownCategories = @("Documents", "Tech Doc", "Compressed", "Programs", "Videos", "Music", "Images", "Fonts", "Others")
    foreach ($cat in $knownCategories) {
        $catDir = Join-Path -Path $targetDir -ChildPath $cat
        if (Test-Path -LiteralPath $catDir -PathType Container) {
            $dirObj = Get-Item -LiteralPath $catDir -Force
            if (-not ($dirObj.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                $children = @(Get-ChildItem -LiteralPath $catDir -Force)
                if ($children.Count -eq 0) {
                    try {
                        [System.IO.Directory]::Delete($catDir)
                        $cleanedDirs.Add($cat)
                    } catch {
                        # Ignore directory deletion errors
                    }
                }
            }
        }
    }
}

# Summary
Write-Host "`n======================= SUMMARY ==========================" -ForegroundColor DarkGray
Write-Host "  Total files restored:      $restoredCount" -ForegroundColor DarkGreen
if ($cleanedDirs.Count -gt 0) {
    Write-Host "  Empty folders pruned:      $($cleanedDirs.Count) ($($cleanedDirs -join ', '))" -ForegroundColor Gray
}
if ($errors.Count -gt 0) {
    Write-Host "`n  Errors encountered:        $($errors.Count)" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "    - $err" -ForegroundColor Red
    }
}
Write-Host "==========================================================" -ForegroundColor DarkGray

# Rotate processed log file to *.txt.undone to support multi-level undo stack
try {
    $undoneLogPath = "$logPath.undone"
    $suffix = 1
    while (Test-Path -LiteralPath $undoneLogPath) {
        $undoneLogPath = "$logPath.$suffix.undone"
        $suffix++
    }
    Move-Item -LiteralPath $logPath -Destination $undoneLogPath -ErrorAction Stop
    Write-Host "`nRotated source log to: $([System.IO.Path]::GetFileName($undoneLogPath))" -ForegroundColor Gray
} catch {
    Write-Host "`nWARNING: Failed to rotate source log: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

# Action Log for Undo
if ($restoredCount -gt 0 -or $errors.Count -gt 0) {
    $now = Get-Date
    $undoTimestamp = $now.ToString("yyyyMMdd_HHmmss")
    $undoLogName = "undo_log_${undoTimestamp}.txt"
    $undoLogPath = Join-Path -Path $targetDir -ChildPath $undoLogName
    $logSuffix = 1
    while (Test-Path -LiteralPath $undoLogPath) {
        $undoLogName = "undo_log_${undoTimestamp}_${logSuffix}.txt"
        $undoLogPath = Join-Path -Path $targetDir -ChildPath $undoLogName
        $logSuffix++
    }

    $sb = [System.Text.StringBuilder]::new()
    $sb.AppendLine("undo_last_action.bat - Run: $($now.ToString('yyyy-MM-dd HH:mm:ss'))") | Out-Null
    $sb.AppendLine("Target folder: $targetDir") | Out-Null
    $sb.AppendLine("Source log processed: $logFileName") | Out-Null
    $sb.AppendLine("Total restored: $restoredCount | Errors: $($errors.Count)") | Out-Null
    if ($cleanedDirs.Count -gt 0) {
        $sb.AppendLine("Pruned empty folders: $($cleanedDirs -join ', ')") | Out-Null
    }
    $sb.AppendLine() | Out-Null
    $sb.AppendLine("[RESTORED]") | Out-Null
    if ($restoredItems.Count -gt 0) {
        foreach ($r in $restoredItems) {
            $sb.AppendLine("  $($r.CurrentPath) -> $($r.OriginalPath)") | Out-Null
        }
    } else {
        $sb.AppendLine("  (none)") | Out-Null
    }
    $sb.AppendLine() | Out-Null
    $sb.AppendLine("[ERRORS]") | Out-Null
    if ($errors.Count -gt 0) {
        foreach ($err in $errors) {
            $sb.AppendLine("  $err") | Out-Null
        }
    } else {
        $sb.AppendLine("  (none)") | Out-Null
    }

    try {
        [System.IO.File]::WriteAllText($undoLogPath, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
        Write-Host "Undo action log written to: $undoLogName" -ForegroundColor DarkCyan
    } catch {
        Write-Host "WARNING: Failed to write undo log: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}
Write-Host ""
