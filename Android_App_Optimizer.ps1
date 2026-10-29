# Dependency check
if (!(Get-Command "adb" -ErrorAction SilentlyContinue)) {
    Write-Host "Error: ADB isn't installed or in your PATH. Fix that shit first." -ForegroundColor Red
    exit
}

# Single-choice menu using pure ANSI relative cursor rewinding with color-coding & legend support
function Show-Menu {
    param (
        [string]$Title,
        [string[]]$Options,
        [int]$DefaultIndex = 0,
        [string]$Legend = "",
        [int[]]$RedIndices = @()
    )

    $selectedIndex = $DefaultIndex
    $esc = [char]27
    $legendLines = if ($Legend) { 2 } else { 0 }
    $totalLines = $Options.Count + 1 + $legendLines

    [Console]::CursorVisible = $false

    # Helper scriptblock to render option items cleanly
    $drawOptions = {
        param([bool]$withAnsiClear)

        if ($Legend) {
            $prefix = if ($withAnsiClear) { "$esc[2K" } else { "" }
            Write-Host "$prefix$Legend" -ForegroundColor Yellow
            Write-Host "$prefix" # spacer line
        }

        $titlePrefix = if ($withAnsiClear) { "$esc[2K" } else { "" }
        Write-Host "$titlePrefix$Title" -ForegroundColor Cyan

        for ($i = 0; $i -lt $Options.Count; $i++) {
            $clear = if ($withAnsiClear) { "$esc[2K" } else { "" }
            if ($i -eq $selectedIndex) {
                # Selected row gets highlighted
                if ($RedIndices -contains $i) {
                    Write-Host "$clear  > $($Options[$i])" -ForegroundColor Red
                } else {
                    Write-Host "$clear  > $($Options[$i])" -ForegroundColor Green
                }
            } else {
                # Unselected rows
                if ($RedIndices -contains $i) {
                    Write-Host "$clear    $($Options[$i])" -ForegroundColor DarkRed
                } else {
                    Write-Host "$clear    $($Options[$i])" -ForegroundColor Gray
                }
            }
        }
    }

    try {
        # Initial draw
        & $drawOptions $false

        while ($true) {
            $keyInfo = [Console]::ReadKey($true)
            $needsRedraw = $false

            switch ($keyInfo.Key) {
                'UpArrow' {
                    if ($selectedIndex -gt 0) {
                        $selectedIndex--
                        $needsRedraw = $true
                    }
                }
                'DownArrow' {
                    if ($selectedIndex -lt ($Options.Count - 1)) {
                        $selectedIndex++
                        $needsRedraw = $true
                    }
                }
                'Enter' {
                    Write-Host ""
                    return $Options[$selectedIndex]
                }
            }

            if ($needsRedraw) {
                [Console]::Write("$esc[${totalLines}A$esc[0G")
                & $drawOptions $true
            }
        }
    }
    finally {
        [Console]::CursorVisible = $true
    }
}

# Formatted Status Reporter
function Get-DexStatus {
    Write-Host "--- Current DEX Compilation Breakdown ---" -ForegroundColor DarkGray
    $raw = adb shell "dumpsys package | grep -oE '\[status=[^] ]+' | cut -d= -f2 | sort | uniq -c"
    if ($raw) {
        $raw | ForEach-Object {
            $line = $_.Trim()
            if ($line -match '^(\d+)\s+(.+)$') {
                $count = $matches[1]
                $status = $matches[2]
                Write-Host ("  {0,4} Apps in '{1}' Status" -f $count, $status) -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "No status available or device unresponsive." -ForegroundColor Red
    }
    Write-Host "-----------------------------------------`n" -ForegroundColor DarkGray
}

# Multi-select package picker with friendly names & live status tagging
function Show-MultiPackagePicker {
    param (
        [array]$PackageItems
    )

    $filter = ""
    $cursor = 0
    $pageHeight = 10
    $selectedSet = [System.Collections.Generic.HashSet[string]]::new()
    $esc = [char]27

    [Console]::Clear()
    [Console]::CursorVisible = $false

    # Static Explainer Banner
    Write-Host "==================== PACKAGE SELECTOR CONTROLS ====================" -ForegroundColor Cyan
    Write-Host "  [Up / Down]    Move selection cursor" -ForegroundColor White
    Write-Host "  [Spacebar]     Toggle package selection ([*] / [ ])" -ForegroundColor White
    Write-Host "  [Typing]       Type characters to filter packages live" -ForegroundColor White
    Write-Host "  [Backspace]    Delete last character from active filter" -ForegroundColor White
    Write-Host "  [Enter]        Confirm and execute on all selected packages" -ForegroundColor Green
    Write-Host "  [Escape]       Cancel operation and exit script" -ForegroundColor Red
    Write-Host "===================================================================" -ForegroundColor Cyan

    $originY = [Console]::CursorTop

    try {
        while ($true) {
            $matching = @(if ([string]::IsNullOrEmpty($filter)) {
                $PackageItems
            } else {
                $PackageItems | Where-Object { $_.SearchText -like "*$filter*" }
            })

            $mCount = $matching.Count
            if ($cursor -ge $mCount) { $cursor = [Math]::Max(0, $mCount - 1) }

            $halfPage = [Math]::Floor($pageHeight / 2)
            $topIndex = [Math]::Max(0, [Math]::Min($cursor - $halfPage, [Math]::Max(0, $mCount - $pageHeight)))
            $bottomIndex = [Math]::Min($mCount, $topIndex + $pageHeight)

            [Console]::SetCursorPosition(0, $originY)

            Write-Host "$esc[2KFilter: " -NoNewline -ForegroundColor White
            Write-Host ("$filter".PadRight(35)) -ForegroundColor Yellow
            Write-Host "$esc[2KSelected: $($selectedSet.Count) / $mCount matching" -ForegroundColor Magenta
            Write-Host "$esc[2K--------------------------------------------------" -ForegroundColor DarkGray

            for ($i = 0; $i -lt $pageHeight; $i++) {
                $itemIdx = $topIndex + $i
                if ($itemIdx -lt $bottomIndex) {
                    $item = $matching[$itemIdx]
                    $pkg = $item.PackageName
                    $isChecked = if ($selectedSet.Contains($pkg)) { "[*]" } else { "[ ]" }
                    $pointer = if ($itemIdx -eq $cursor) { " > " } else { "   " }

                    $displayLabel = if ($item.DisplayName -ne $pkg) {
                        "$($item.DisplayName) ($pkg)"
                    } else {
                        $pkg
                    }
                    $statusTag = "[$($item.Status)]"
                    $line = "$pointer$isChecked $displayLabel $statusTag"

                    $maxWidth = [Math]::Max(10, [Console]::WindowWidth - 2)
                    if ($line.Length -gt $maxWidth) {
                        $line = $line.Substring(0, $maxWidth - 3) + "..."
                    }

                    if ($itemIdx -eq $cursor) {
                        Write-Host "$esc[2K$line" -ForegroundColor Green
                    } elseif ($selectedSet.Contains($pkg)) {
                        Write-Host "$esc[2K$line" -ForegroundColor Yellow
                    } else {
                        Write-Host "$esc[2K$line" -ForegroundColor Gray
                    }
                } else {
                    Write-Host "$esc[2K"
                }
            }

            $key = [Console]::ReadKey($true)

            switch ($key.Key) {
                'UpArrow' {
                    if ($cursor -gt 0) { $cursor-- }
                }
                'DownArrow' {
                    if ($cursor -lt ($mCount - 1)) { $cursor++ }
                }
                'Spacebar' {
                    if ($mCount -gt 0) {
                        $target = $matching[$cursor].PackageName
                        if ($selectedSet.Contains($target)) {
                            [void]$selectedSet.Remove($target)
                        } else {
                            [void]$selectedSet.Add($target)
                        }
                    }
                }
                'Enter' {
                    if ($selectedSet.Count -eq 0 -and $mCount -gt 0) {
                        [void]$selectedSet.Add($matching[$cursor].PackageName)
                    }
                    [Console]::Clear()
                    return @($selectedSet)
                }
                'Escape' {
                    [Console]::Clear()
                    Write-Host "Operation canceled by user." -ForegroundColor Yellow
                    exit
                }
                'Backspace' {
                    if ($filter.Length -gt 0) {
                        $filter = $filter.Substring(0, $filter.Length - 1)
                        $cursor = 0
                    }
                }
                default {
                    if (-not [char]::IsControl($key.KeyChar)) {
                        $filter += $key.KeyChar
                        $cursor = 0
                    }
                }
            }
        }
    }
    finally {
        [Console]::CursorVisible = $true
    }
}

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "           ADB App Optimizer          " -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

Write-Host "Parsing package manifest and DEX metadata from device..." -ForegroundColor Cyan

# Parse current status mapping
$statusDump = adb shell "dumpsys package"
$statusMap = @{}
$currentPkg = $null

foreach ($line in ($statusDump -split "`n")) {
    $cleanLine = $line.Trim()
    if ($cleanLine -match '^\[([a-zA-Z0-9._]+)\]$') {
        $currentPkg = $matches[1]
    } elseif ($currentPkg -and $cleanLine -match '\[status=([^] ]+)\]') {
        if (-not $statusMap.ContainsKey($currentPkg)) {
            $statusMap[$currentPkg] = $matches[1]
        }
    }
}

# Fetch packages
$allPackages = (adb shell pm list packages) -replace '^package:','' -replace "`r",'' | Where-Object { $_ -ne '' } | Sort-Object

if ($allPackages.Count -eq 0) {
    Write-Host "No packages found. Is your device plugged in and authorized via ADB?" -ForegroundColor Red
    exit
}

# Build rich package objects
$packageObjects = @()
foreach ($pkg in $allPackages) {
    $stat = if ($statusMap.ContainsKey($pkg)) { $statusMap[$pkg] } else { "unknown" }
    $cleanName = $pkg -replace '^com\.(google\.android|android)\.', '' -replace '^com\.', ''
    
    $packageObjects += [PSCustomObject]@{
        PackageName = $pkg
        DisplayName = $cleanName
        Status      = $stat
        SearchText  = "$cleanName $pkg"
    }
}

# 1. Target Selector: All vs Specific
$scopeChoice = Show-Menu -Title "Select operation target:" -Options @("All Installed Packages", "Select Specific Package(s)") -DefaultIndex 0

$targetPackages = @()

if ($scopeChoice -eq "All Installed Packages") {
    $targetPackages = $allPackages
    $targetAction = "Optimize"
} else {
    $targetPackages = Show-MultiPackagePicker -PackageItems $packageObjects
    if ($targetPackages.Count -eq 0) {
        Write-Host "No packages selected. Exiting." -ForegroundColor Yellow
        exit
    }

    $targetAction = Show-Menu -Title "Choose action for $($targetPackages.Count) selected package(s):" -Options @("Optimize DEX", "Reset DEX (Wipe compiled artifacts)") -DefaultIndex 0
}

# 2. Reset Pipeline Fork
if ($targetAction -like "Reset DEX*") {
    Write-Host "Capturing pre-reset DEX status..." -ForegroundColor Cyan
    Get-DexStatus

    Write-Host "Resetting DEX compilation on $($targetPackages.Count) package(s)..." -ForegroundColor Yellow
    $count = 0
    foreach ($pkg in $targetPackages) {
        $count++
        $percent = [math]::Round(($count / $targetPackages.Count) * 100)
        Write-Progress -Activity "ADB Dex Reset" -Status "Resetting: $pkg ($count/$($targetPackages.Count))" -PercentComplete $percent

        $null = adb shell cmd package compile --reset $pkg 2>&1
    }
    Write-Progress -Activity "ADB Dex Reset" -Completed

    Write-Host "`nReset completed for $($targetPackages.Count) package(s)!" -ForegroundColor Green
    Write-Host "Capturing post-reset DEX status..." -ForegroundColor Cyan
    Get-DexStatus
    exit
}

# 3. Compilation Filter Selector with color coding & top legend
$dexFilterOptions = @(
    "extract       - Extracts DEX files from APK without compiling",
    "verify        - Bytecode safety check & .vdex only; runs via interpreter/JIT",
    "quicken       - Bytecode verification + basic opcode optimizations",
    "space-profile - Profile-guided compilation tuned to minimize disk usage",
    "space         - Full AOT compilation prioritizing smaller file size",
    "speed-profile - Profile-guided AOT on hot methods (Play Store + local .prof)",
    "speed         - Full AOT compilation of all methods to native machine code",
    "everything    - Aggressive AOT compiling all code, cold paths & debug data"
)

# Indices 0, 1, 2 (extract, verify, quicken) and 7 (everything) are flagged red
$redFilterIndices = @(0, 1, 2, 7)
$filterLegend = "[Legend] Items in RED are NOT recommended for general performance optimization."

# Preselect "speed" (Index 6)
$selectedFilterLine = Show-Menu `
    -Title "Select optimization filter (Use Up/Down arrows and Enter):" `
    -Options $dexFilterOptions `
    -DefaultIndex 6 `
    -Legend $filterLegend `
    -RedIndices $redFilterIndices

# Extract pure filter name (e.g. "speed")
$mode = ($selectedFilterLine -split '\s+-\s+')[0].Trim()

# 4. Secondary Dex Selector
$secChoice = Show-Menu -Title "Optimize secondary app code (--secondary-dex):" -Options @("Yes", "No") -DefaultIndex 0
$secondaryFlag = if ($secChoice -eq "Yes") { "--secondary-dex" } else { "" }

# 5. Force Recompilation Selector (Default: No)
$forceChoice = Show-Menu -Title "Force recompilation (-f)? Overwrites already-optimized packages:" -Options @("Yes", "No") -DefaultIndex 1
$forceFlag = if ($forceChoice -eq "Yes") { "-f" } else { "" }

# Baseline Status Snapshot
Write-Host "Capturing baseline DEX status..." -ForegroundColor Cyan
Get-DexStatus

$total = $targetPackages.Count
Write-Host "Targeting $total package(s) with filter: $mode"
Write-Host "Force recompilation (-f): $(if($forceFlag){'ENABLED'}else{'DISABLED'})"
Write-Host "Secondary dex pass: $(if($secondaryFlag){'ENABLED'}else{'DISABLED'})`n"

$count = 0
foreach ($pkg in $targetPackages) {
    $count++
    $percent = [math]::Round(($count / $total) * 100)
    
    Write-Progress -Activity "ADB Optimization" -Status "Compiling: $pkg ($count/$total)" -PercentComplete $percent

    # Build primary command array
    $cmd = @("cmd", "package", "compile", "-m", $mode)
    if ($forceFlag) { $cmd += $forceFlag }
    $cmd += $pkg

    # Pass 1: Primary compilation
    $null = adb shell $cmd 2>&1
    
    # Pass 2: Secondary dex (if enabled)
    if ($secondaryFlag) {
        $secCmd = @("cmd", "package", "compile", "-m", $mode)
        if ($forceFlag) { $secCmd += $forceFlag }
        $secCmd += $secondaryFlag
        $secCmd += $pkg
        $null = adb shell $secCmd 2>&1
    }
}

Write-Progress -Activity "ADB Optimization" -Completed
Write-Host "All $total package(s) successfully processed!`n" -ForegroundColor Green

# Final Status Snapshot
Write-Host "Capturing final DEX status..." -ForegroundColor Cyan
Get-DexStatus

Write-Host "Optimization complete!" -ForegroundColor Green
