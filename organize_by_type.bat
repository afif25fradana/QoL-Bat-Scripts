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
Write-Host "               FILE TYPE AUTO-ORGANIZER                   " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor DarkGray
Write-Host "Target Folder: $targetDir`n" -ForegroundColor Gray

# Category Mapping
$categoryMapping = [ordered]@{
    "Documents"  = @(".pdf", ".doc", ".docx", ".xlsx", ".xls", ".ppt", ".pptx", ".txt", ".csv", ".rtf", ".odt", ".epub", ".mobi", ".tsv", ".docm", ".xlsm")
    "Tech Doc"   = @(".html", ".htm", ".json", ".md")
    "Compressed" = @(".zip", ".rar", ".7z", ".tar", ".gz", ".iso", ".xz", ".bz2", ".tgz")
    "Programs"   = @(".exe", ".msi", ".mcaddon", ".mcpack", ".apk", ".appx", ".msix", ".jar")
    "Videos"     = @(".mp4", ".mkv", ".avi", ".mov", ".webm", ".ts", ".3gp", ".m4v", ".wmv", ".flv")
    "Music"      = @(".mp3", ".wav", ".flac", ".opus", ".m4a", ".ogg", ".aac")
    "Images"     = @(".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".bmp", ".avif", ".ico", ".heic", ".heif", ".tiff", ".tif", ".raw")
}

# Resolve running script path to exclude itself
$runningScriptPath = ""
if ($env:SCRIPT_PATH -and (Test-Path -LiteralPath $env:SCRIPT_PATH)) {
    $runningScriptPath = (Get-Item -LiteralPath $env:SCRIPT_PATH).FullName
}

# Files and extensions to ignore (companion scripts, system files, shortcuts, version control)
$ignoredFileNames = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@("desktop.ini", "Thumbs.db", ".gitignore", ".gitattributes", ".gitmodules"),
    [System.StringComparer]::OrdinalIgnoreCase
)
$ignoredExtensions = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@(".bat", ".cmd", ".ps1", ".sh", ".lnk", ".url"),
    [System.StringComparer]::OrdinalIgnoreCase
)

# Get loose files directly in the root of target folder (non-recursive)
$allLooseFiles = @(Get-ChildItem -LiteralPath $targetDir -File | Where-Object {
    if ($runningScriptPath -and $_.FullName -eq $runningScriptPath) {
        return $false
    }
    if ($ignoredFileNames.Contains($_.Name)) {
        return $false
    }
    if ($ignoredExtensions.Contains($_.Extension)) {
        return $false
    }
    return $true
})

if ($allLooseFiles.Count -eq 0) {
    Write-Host "No loose files found in target folder to organize." -ForegroundColor DarkGreen
    Write-Host ""
    return
}

# Pre-load existing filenames in destination folders to detect collisions
$allCategories = @($categoryMapping.Keys) + @("Others")
$usedNamesPerCategory = @{}

foreach ($cat in $allCategories) {
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $catDir = Join-Path -Path $targetDir -ChildPath $cat
    if (Test-Path -LiteralPath $catDir) {
        Get-ChildItem -LiteralPath $catDir -File | ForEach-Object {
            $set.Add($_.Name) | Out-Null
        }
    }
    $usedNamesPerCategory[$cat] = $set
}

$plan = [System.Collections.Generic.List[PSCustomObject]]::new()
$totalCollisions = 0
$categoryCounts = [ordered]@{}
foreach ($cat in $allCategories) {
    $categoryCounts[$cat] = 0
}

# Build migration plan
foreach ($file in $allLooseFiles) {
    $ext = $file.Extension.ToLower()
    $category = "Others"
    
    foreach ($catName in $categoryMapping.Keys) {
        if ($categoryMapping[$catName] -contains $ext) {
            $category = $catName
            break
        }
    }
    
    $baseName = $file.BaseName
    $rawExt = $file.Extension
    $targetName = $file.Name
    $isCollision = $false
    
    $usedSet = $usedNamesPerCategory[$category]
    if ($usedSet.Contains($targetName)) {
        $isCollision = $true
        $suffix = 1
        $candidateName = if ([string]::IsNullOrEmpty($baseName)) { "${targetName}_${suffix}" } else { "${baseName}_${suffix}${rawExt}" }
        while ($usedSet.Contains($candidateName)) {
            $suffix++
            $candidateName = if ([string]::IsNullOrEmpty($baseName)) { "${targetName}_${suffix}" } else { "${baseName}_${suffix}${rawExt}" }
        }
        $targetName = $candidateName
        $totalCollisions++
    }

    $usedSet.Add($targetName) | Out-Null
    $categoryCounts[$category]++
    
    $plan.Add([PSCustomObject]@{
        File           = $file
        OriginalName   = $file.Name
        Category       = $category
        TargetFileName = $targetName
        IsCollision    = $isCollision
    })
}

# Display Preview grouped by Category
Write-Host "PREVIEW OF PLANNED ACTIONS ($($plan.Count) file(s)):`n" -ForegroundColor White

foreach ($cat in $allCategories) {
    $itemsInCat = @($plan | Where-Object { $_.Category -eq $cat })
    if ($itemsInCat.Count -gt 0) {
        Write-Host "  [$cat] ($($itemsInCat.Count) file(s)):" -ForegroundColor DarkCyan
        foreach ($item in $itemsInCat) {
            $tag = if ($item.IsCollision) { " [Collision resolved]" } else { "" }
            Write-Host "    $($item.OriginalName)" -NoNewline -ForegroundColor Gray
            Write-Host " -> " -NoNewline -ForegroundColor DarkGray
            Write-Host "$($item.Category)/$($item.TargetFileName)" -NoNewline -ForegroundColor DarkCyan
            if ($tag) {
                Write-Host "$tag" -ForegroundColor DarkYellow
            } else {
                Write-Host ""
            }
        }
        Write-Host ""
    }
}

# Summary table before confirmation
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "SUMMARY BY CATEGORY:" -ForegroundColor White
foreach ($cat in $allCategories) {
    if ($categoryCounts[$cat] -gt 0) {
        Write-Host "  - $($cat.PadRight(14)): $($categoryCounts[$cat])" -ForegroundColor Gray
    }
}
Write-Host ""
Write-Host "Total files to move: $($plan.Count) | Collisions resolved: $totalCollisions" -ForegroundColor White
Write-Host "----------------------------------------------------------`n" -ForegroundColor DarkGray

# Prompt confirmation
$response = Read-Host "Do you want to proceed with organizing these $($plan.Count) file(s)? [y/N]"

if ($null -eq $response -or $response.Trim() -notmatch '^(y|yes)$') {
    Write-Host "`nOperation cancelled by user. No files were moved." -ForegroundColor Red
    Write-Host ""
    return
}

# Execute move
$movedCount = 0
$errors = [System.Collections.Generic.List[string]]::new()
$successCounts = [ordered]@{}
foreach ($cat in $allCategories) {
    $successCounts[$cat] = 0
}

Write-Host "`nMoving files..." -ForegroundColor Gray

foreach ($item in $plan) {
    try {
        $destDir = Join-Path -Path $targetDir -ChildPath $item.Category
        if (-not (Test-Path -LiteralPath $destDir)) {
            [System.IO.Directory]::CreateDirectory($destDir) | Out-Null
        }
        $destPath = Join-Path -Path $destDir -ChildPath $item.TargetFileName
        Move-Item -LiteralPath $item.File.FullName -Destination $destPath -ErrorAction Stop
        $movedCount++
        $successCounts[$item.Category]++
    } catch {
        $errors.Add("Failed to move '$($item.OriginalName)' to '$($item.Category)/$($item.TargetFileName)': $($_.Exception.Message)")
    }
}

# Summary
Write-Host "`n======================= SUMMARY ==========================" -ForegroundColor DarkGray
Write-Host "  Total files moved:         $movedCount" -ForegroundColor DarkGreen
Write-Host "  Collisions resolved:       $totalCollisions" -ForegroundColor DarkYellow
Write-Host "`n  Breakdown by category:" -ForegroundColor White
foreach ($cat in $allCategories) {
    if ($successCounts[$cat] -gt 0) {
        Write-Host "    - $($cat.PadRight(14)): $($successCounts[$cat])" -ForegroundColor Gray
    }
}

if ($errors.Count -gt 0) {
    Write-Host "`n  Errors encountered:        $($errors.Count)" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "    - $err" -ForegroundColor Red
    }
}
Write-Host "==========================================================" -ForegroundColor DarkGray
Write-Host ""
