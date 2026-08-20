<# :
@echo off
setlocal
set "SCRIPT_PATH=%~f0"
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "[ScriptBlock]::Create((Get-Content -LiteralPath $env:SCRIPT_PATH -Raw)).Invoke()"
pause
exit /b %ERRORLEVEL%
#>

$ErrorActionPreference = "Stop"

# Target directory is the folder where this .bat file resides
$targetDir = Split-Path -Parent $env:SCRIPT_PATH
if (-not $targetDir -or -not (Test-Path -LiteralPath $targetDir)) {
    $targetDir = (Get-Location).Path
}

Write-Host "==========================================================" -ForegroundColor DarkGray
Write-Host "         SCREENSHOT TIMESTAMP BATCH RENAMER               " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor DarkGray
Write-Host "Target Folder: $targetDir`n" -ForegroundColor Gray

# Allowed image extensions (case-insensitive)
$validExtensions = @(".png", ".jpg", ".jpeg")

# Pattern for files already named correctly (e.g., 2024-03-15_14-30-45.png or 2024-03-15_14-30-45_1.png)
$alreadyFormattedRegex = '^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}(_\d+)?\.(png|jpg|jpeg)$'

# Get all files in target folder (non-recursive)
$allFiles = Get-ChildItem -LiteralPath $targetDir -File

# Filter image files
$imageFiles = @($allFiles | Where-Object { $validExtensions -contains $_.Extension.ToLower() })

if ($imageFiles.Count -eq 0) {
    Write-Host "No image files (.png, .jpg, .jpeg) found in target folder." -ForegroundColor DarkYellow
    Write-Host ""
    return
}

$plan = [System.Collections.Generic.List[PSCustomObject]]::new()
$skippedCount = 0
$collisionCount = 0

# Track target filenames to prevent in-batch collisions and collisions with existing files
$usedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($f in $allFiles) {
    $usedNames.Add($f.Name) | Out-Null
}

$filesToProcess = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

foreach ($file in $imageFiles) {
    if ($file.Name -match $alreadyFormattedRegex) {
        $skippedCount++
    } else {
        $filesToProcess.Add($file)
    }
}

if ($filesToProcess.Count -eq 0) {
    Write-Host "All $($imageFiles.Count) image file(s) are already formatted correctly. Nothing to rename." -ForegroundColor DarkGreen
    Write-Host "Skipped (already formatted): $skippedCount file(s)." -ForegroundColor Gray
    Write-Host ""
    return
}

# Remove the files we are going to rename from the usedNames set
foreach ($file in $filesToProcess) {
    $usedNames.Remove($file.Name) | Out-Null
}

# Determine new names and resolve collisions
foreach ($file in $filesToProcess) {
    $ext = $file.Extension.ToLower()
    $baseTimestamp = $file.LastWriteTime.ToString("yyyy-MM-dd_HH-mm-ss")
    $targetName = "${baseTimestamp}${ext}"
    
    $isCollision = $false
    if ($usedNames.Contains($targetName)) {
        $isCollision = $true
        $suffix = 1
        while ($usedNames.Contains("${baseTimestamp}_${suffix}${ext}")) {
            $suffix++
        }
        $targetName = "${baseTimestamp}_${suffix}${ext}"
        $collisionCount++
    }
    
    $usedNames.Add($targetName) | Out-Null
    
    $plan.Add([PSCustomObject]@{
        File = $file
        OldName = $file.Name
        NewName = $targetName
        IsCollision = $isCollision
    })
}

# Display preview
Write-Host "PREVIEW OF PLANNED RENAMES ($($plan.Count) file(s)):`n" -ForegroundColor White
foreach ($item in $plan) {
    $tag = if ($item.IsCollision) { " [Collision resolved]" } else { "" }
    Write-Host "  $($item.OldName)" -NoNewline -ForegroundColor Gray
    Write-Host " -> " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($item.NewName)" -NoNewline -ForegroundColor DarkCyan
    if ($tag) {
        Write-Host "$tag" -ForegroundColor DarkYellow
    } else {
        Write-Host ""
    }
}

Write-Host ""
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "Planned Renames: $($plan.Count) | Skipped (already formatted): $skippedCount | Collisions: $collisionCount" -ForegroundColor White
Write-Host "----------------------------------------------------------`n" -ForegroundColor DarkGray

# Prompt confirmation
$response = Read-Host "Do you want to proceed with renaming these $($plan.Count) file(s)? [y/N]"

if ($null -eq $response -or $response.Trim() -notmatch '^(y|yes)$') {
    Write-Host "`nOperation cancelled by user. No files were modified." -ForegroundColor Red
    Write-Host ""
    return
}

# Execute rename
$renamedCount = 0
$errors = [System.Collections.Generic.List[string]]::new()

Write-Host "`nRenaming files..." -ForegroundColor Gray

foreach ($item in $plan) {
    try {
        Rename-Item -LiteralPath $item.File.FullName -NewName $item.NewName -ErrorAction Stop
        $renamedCount++
    } catch {
        $errors.Add("Failed to rename '$($item.OldName)': $($_.Exception.Message)")
    }
}

# Summary
Write-Host "`n======================= SUMMARY ==========================" -ForegroundColor DarkGray
Write-Host "  Files renamed:             $renamedCount" -ForegroundColor DarkGreen
Write-Host "  Files skipped:             $skippedCount" -ForegroundColor Gray
Write-Host "  Collisions resolved:       $collisionCount" -ForegroundColor DarkYellow
if ($errors.Count -gt 0) {
    Write-Host "  Errors encountered:        $($errors.Count)" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "    - $err" -ForegroundColor Red
    }
}
Write-Host "==========================================================" -ForegroundColor DarkGray
Write-Host ""
