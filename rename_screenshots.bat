<# :
@echo off
setlocal
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
    Write-Host "CRITICAL ERROR: Cannot determine the script's directory securely. Execution aborted." -ForegroundColor Red
    return
}

# Defense-in-depth: refuse to operate unless the script at $env:SCRIPT_PATH is a valid polyglot.
# This prevents operating on a stale/forged SCRIPT_PATH when the PowerShell body is run standalone.
if (($env:SCRIPT_PATH) -and (Test-Path -LiteralPath $env:SCRIPT_PATH) -and (Get-Content -LiteralPath $env:SCRIPT_PATH -TotalCount 1) -notmatch '^<# :') {
    Write-Host "CRITICAL ERROR: '$env:SCRIPT_PATH' is not a valid QoL script (missing polyglot header). Execution aborted." -ForegroundColor Red
    Write-Host ""
    return
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

# Track target filenames to prevent in-batch collisions and collisions with existing files/folders
$usedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
Get-ChildItem -LiteralPath $targetDir | ForEach-Object {
    $usedNames.Add($_.Name) | Out-Null
}

$filesToProcess = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
$skippedReservedNames = [System.Collections.Generic.List[string]]::new()

foreach ($file in $imageFiles) {
    if (Test-ReservedName -Name $file.Name) {
        $skippedReservedNames.Add($file.Name)
        continue
    }
    if ($file.Name -match $alreadyFormattedRegex) {
        $skippedCount++
    } else {
        $filesToProcess.Add($file)
    }
}

if ($skippedReservedNames.Count -gt 0) {
    Write-Host "SKIPPED (Windows reserved device name, cannot be renamed):" -ForegroundColor DarkYellow
    foreach ($name in $skippedReservedNames) {
        Write-Host "  - $(Get-SafeDisplayName $name)" -ForegroundColor DarkYellow
    }
    Write-Host ""
}

if ($filesToProcess.Count -eq 0) {
    Write-Host "All $($imageFiles.Count) image file(s) are already formatted correctly. Nothing to rename." -ForegroundColor DarkGreen
    Write-Host "Skipped (already formatted): $skippedCount file(s)." -ForegroundColor Gray
    Write-Host ""
    return
}

$exifAvailable = $false
try {
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $exifAvailable = $null -ne (@([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'System.Drawing' }))
} catch {
    $exifAvailable = $false
}
if (-not $exifAvailable) {
    Write-Host "NOTE: System.Drawing (GDI+) is unavailable - EXIF Date Taken cannot be read; using Last Modified time for all images." -ForegroundColor DarkYellow
    Write-Host ""
}

# Attempt to extract EXIF Date Taken (DateTimeOriginal/DateTimeDigitized) for photo files
function Get-ExifDateTaken([string]$filePath) {
    try {
        $fileStream = [System.IO.File]::Open($filePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $img = [System.Drawing.Image]::FromStream($fileStream, $false, $false)
            try {
                # 36867 = DateTimeOriginal, 36868 = DateTimeDigitized, 306 = DateTime
                $propIds = @(36867, 36868, 306)
                foreach ($id in $propIds) {
                    if ($img.PropertyIdList -contains $id) {
                        $prop = $img.GetPropertyItem($id)
                        if ($prop -and $prop.Value) {
                            $dateStr = [System.Text.Encoding]::ASCII.GetString($prop.Value).Trim(" `t`r`n`0")
                            $parsedDate = [datetime]::MinValue
                            if ([datetime]::TryParseExact($dateStr, "yyyy:MM:dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
                                if ($parsedDate.Year -ge 1990) {
                                    return $parsedDate
                                }
                            }
                            if ([datetime]::TryParse($dateStr, [ref]$parsedDate)) {
                                if ($parsedDate.Year -ge 1990) {
                                    return $parsedDate
                                }
                            }
                        }
                    }
                }
            } finally {
                if ($null -ne $img) { $img.Dispose() }
            }
        } finally {
            if ($null -ne $fileStream) { $fileStream.Dispose() }
        }
    } catch {
        # Silently fall back if EXIF is missing, corrupt, or unreadable
    }
    return $null
}

# Determine new names and resolve collisions (existing filenames are kept in $usedNames to prevent overwriting or race conditions)
foreach ($file in $filesToProcess) {
    $ext = $file.Extension.ToLower()
    
    $timestampDate = $null
    if ($ext -eq ".jpg" -or $ext -eq ".jpeg") {
        $timestampDate = Get-ExifDateTaken -filePath $file.FullName
    }
    if ($null -eq $timestampDate) {
        $timestampDate = $file.LastWriteTime
    }
    
    $baseTimestamp = $timestampDate.ToString("yyyy-MM-dd_HH-mm-ss")
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
    Write-Host "  $(Get-SafeDisplayName $item.OldName)" -NoNewline -ForegroundColor Gray
    Write-Host " -> " -NoNewline -ForegroundColor DarkGray
    Write-Host "$(Get-SafeDisplayName $item.NewName)" -NoNewline -ForegroundColor DarkCyan
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
    if ($item.OldName -ieq $item.NewName) {
        continue
    }
    try {
        Rename-Item -LiteralPath $item.File.FullName -NewName $item.NewName -ErrorAction Stop
        $renamedCount++
    } catch {
        $errors.Add("Failed to rename '$(Get-SafeDisplayName $item.OldName)': $($_.Exception.Message)")
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
