@echo off
setlocal

REM ============================================================
REM R36S / RK3326 overclock installer for Windows
REM ============================================================

set "DTC=%~dp0dtc.exe"
set "DTB=%~dp0rk3326-r36s-linux.dtb"
set "DTB_BAK=%~dp0rk3326-r36s-linux.dtb.original"
set "IMAGE=%~dp0Image"
set "IMAGE_BAK=%~dp0Image.original"
set "IMAGE_OC=%~dp0Image.oc"

set "SELF=%~f0"
set "PS1TEMP=%TEMP%\r36s_oc_installer_%RANDOM%.ps1"

echo.
echo ============================================================
echo R36S / RK3326 overclock installer
echo ============================================================
echo.

REM Extract the embedded PowerShell payload from this BAT itself.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$self=$env:SELF; $out=$env:PS1TEMP; $lines=Get-Content -LiteralPath $self; $marker='### POWERSHELL_PAYLOAD_BEGIN'; $idx=[Array]::IndexOf($lines,$marker); if($idx -lt 0){Write-Host 'ERROR: PowerShell payload marker not found.'; exit 1}; $payload=$lines[($idx+1)..($lines.Count-1)] -join [Environment]::NewLine; Set-Content -LiteralPath $out -Value $payload -Encoding UTF8"

if errorlevel 1 (
    echo ERROR: could not extract the embedded PowerShell payload.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1TEMP%" ^
  -Dtc "%DTC%" ^
  -Dtb "%DTB%" ^
  -DtbBackup "%DTB_BAK%" ^
  -Image "%IMAGE%" ^
  -ImageBackup "%IMAGE_BAK%" ^
  -ImageOc "%IMAGE_OC%"

set "ERR=%ERRORLEVEL%"

del "%PS1TEMP%" >nul 2>&1

echo.
if not "%ERR%"=="0" (
    echo Installation failed with error code %ERR%.
    pause
    exit /b %ERR%
)

echo Done.
pause
exit /b 0

### POWERSHELL_PAYLOAD_BEGIN
param(
    [string]$Dtc,
    [string]$Dtb,
    [string]$DtbBackup,
    [string]$Image,
    [string]$ImageBackup,
    [string]$ImageOc
)

$ErrorActionPreference = "Stop"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host "ERROR: $Message"
    exit 1
}

function Replace-First {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Replacement,
        [string]$Label
    )

    $rx = [regex]::new($Pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $m = $rx.Match($Text)

    if (-not $m.Success) {
        Stop-WithMessage "Could not apply change: $Label"
    }

    return $rx.Replace($Text, $Replacement, 1)
}

function Find-NodeRange {
    param(
        [string]$Text,
        [string]$NodeName
    )

    $idx = $Text.IndexOf($NodeName + " {")
    if ($idx -lt 0) {
        $idx = $Text.IndexOf($NodeName + "{")
    }

    if ($idx -lt 0) {
        return $null
    }

    $brace = $Text.IndexOf("{", $idx)
    $depth = 0

    for ($i = $brace; $i -lt $Text.Length; $i++) {
        $ch = $Text[$i]

        if ($ch -eq "{") {
            $depth++
        } elseif ($ch -eq "}") {
            $depth--

            if ($depth -eq 0) {
                $end = $Text.IndexOf(";", $i)

                if ($end -lt 0) {
                    $end = $i
                } else {
                    $end++
                }

                return @{
                    Start = $idx
                    End   = $end
                    Node  = $Text.Substring($idx, $end - $idx)
                }
            }
        }
    }

    return $null
}

function Replace-Property-In-Node {
    param(
        [string]$Text,
        [string]$NodeName,
        [string]$PropertyName,
        [string]$NewValue,
        [string]$Label
    )

    $range = Find-NodeRange -Text $Text -NodeName $NodeName

    if ($null -eq $range) {
        Stop-WithMessage "Could not find node: $NodeName"
    }

    $node = $range.Node

    $pattern = "($([regex]::Escape($PropertyName))\s*=\s*)<[^;]+>;"
    $replacement = '${1}' + $NewValue + ';'

    $rx = [regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $m = $rx.Match($node)

    if (-not $m.Success) {
        Stop-WithMessage "Could not find property $PropertyName inside node $NodeName ($Label)"
    }

    $newNode = $rx.Replace($node, $replacement, 1)

    return $Text.Substring(0, $range.Start) + $newNode + $Text.Substring($range.End)
}

function Opp-Block {
    param(
        [int64]$Freq,
        [int]$Uv
    )

    $freqHex = "{0:x}" -f $Freq
    $uvHex = "{0:x}" -f $Uv

    return @"

		opp-$Freq {
			opp-hz = <0x00 0x$freqHex>;
			opp-microvolt = <0x$uvHex 0x$uvHex 0x$uvHex>;
			opp-microvolt-L0 = <0x$uvHex 0x$uvHex 0x$uvHex>;
			opp-microvolt-L1 = <0x$uvHex 0x$uvHex 0x$uvHex>;
			opp-microvolt-L2 = <0x$uvHex 0x$uvHex 0x$uvHex>;
			opp-microvolt-L3 = <0x$uvHex 0x$uvHex 0x$uvHex>;
			clock-latency-ns = <0x9c40>;
		};
"@
}

function Normalize-Or-Add-Opp {
    param(
        [string]$Text,
        [int64]$Freq,
        [int]$Uv,
        [int64]$AnchorFreq
    )

    $name = "opp-$Freq"
    $range = Find-NodeRange -Text $Text -NodeName $name
    $newNode = (Opp-Block -Freq $Freq -Uv $Uv).Trim("`r", "`n")

    if ($null -ne $range) {
        return $Text.Substring(0, $range.Start) + $newNode + $Text.Substring($range.End)
    }

    $anchorName = "opp-$AnchorFreq"
    $anchor = Find-NodeRange -Text $Text -NodeName $anchorName

    if ($null -eq $anchor) {
        Stop-WithMessage "Could not find anchor $anchorName to insert $name"
    }

    return $Text.Substring(0, $anchor.End) + "`r`n" + (Opp-Block -Freq $Freq -Uv $Uv) + $Text.Substring($anchor.End)
}

function Assert-Patched-Dts {
    param([string]$Text)

    $cpuOpp = Find-NodeRange -Text $Text -NodeName "cpu0-opp-table"
    if ($null -eq $cpuOpp) {
        Stop-WithMessage "Verification failed: cpu0-opp-table not found."
    }

    if ($cpuOpp.Node -notmatch 'rockchip,max-volt\s*=\s*<0x155cc0>;') {
        Stop-WithMessage "Verification failed: cpu0-opp-table rockchip,max-volt is not 1400000 uV."
    }

    $dcdc = Find-NodeRange -Text $Text -NodeName "DCDC_REG2"
    if ($null -eq $dcdc) {
        Stop-WithMessage "Verification failed: DCDC_REG2 not found."
    }

    if ($dcdc.Node -notmatch 'regulator-max-microvolt\s*=\s*<0x155cc0>;') {
        Stop-WithMessage "Verification failed: DCDC_REG2 regulator-max-microvolt is not 1400000 uV."
    }

    $requiredOpps = @(
        @{ Freq = 1368000000; Uv = 1350000 },
        @{ Freq = 1416000000; Uv = 1400000 },
        @{ Freq = 1440000000; Uv = 1400000 },
        @{ Freq = 1464000000; Uv = 1400000 },
        @{ Freq = 1488000000; Uv = 1400000 },
        @{ Freq = 1512000000; Uv = 1400000 }
    )

    foreach ($opp in $requiredOpps) {
        $freq = [int64]$opp.Freq
        $uv = [int]$opp.Uv
        $uvHex = "{0:x}" -f $uv

        $node = Find-NodeRange -Text $Text -NodeName "opp-$freq"
        if ($null -eq $node) {
            Stop-WithMessage "Verification failed: opp-$freq not found."
        }

        if ($node.Node -notmatch "opp-microvolt\s*=\s*<0x$uvHex 0x$uvHex 0x$uvHex>;") {
            Stop-WithMessage "Verification failed: opp-$freq target voltage is not $uv uV."
        }
    }

    Write-Host "DTS verification passed."
}

Write-Host "[1/6] Checking required files..."

if (-not (Test-Path -LiteralPath $Dtc)) {
    Stop-WithMessage "dtc.exe was not found in this folder."
}

if (-not (Test-Path -LiteralPath $Dtb)) {
    Stop-WithMessage "rk3326-r36s-linux.dtb was not found in this folder."
}

if (-not (Test-Path -LiteralPath $Image)) {
    Stop-WithMessage "Image was not found in this folder."
}

if (-not (Test-Path -LiteralPath $ImageOc)) {
    Stop-WithMessage "Image.oc was not found in this folder."
}

Write-Host ""
Write-Host "[2/6] Backing up DTB..."

if (Test-Path -LiteralPath $DtbBackup) {
    Write-Host "Backup already exists: rk3326-r36s-linux.dtb.original"
    Write-Host "Keeping existing backup."
} else {
    Copy-Item -LiteralPath $Dtb -Destination $DtbBackup -Force
    Write-Host "Created: rk3326-r36s-linux.dtb.original"
}

Write-Host ""
Write-Host "[3/6] Backing up Image..."

if (Test-Path -LiteralPath $ImageBackup) {
    Write-Host "Backup already exists: Image.original"
    Write-Host "Keeping existing backup."
} else {
    Copy-Item -LiteralPath $Image -Destination $ImageBackup -Force
    Write-Host "Created: Image.original"
}

$tmpDts = Join-Path $env:TEMP ("r36s_dtb_patch_" + [System.Guid]::NewGuid().ToString("N") + ".dts")
$tmpDtb = Join-Path $env:TEMP ("r36s_dtb_patch_" + [System.Guid]::NewGuid().ToString("N") + ".dtb")
$checkDts = Join-Path $env:TEMP ("r36s_dtb_check_" + [System.Guid]::NewGuid().ToString("N") + ".dts")

Write-Host ""
Write-Host "[4/6] Decompiling DTB..."

& $Dtc -I dtb -O dts -o $tmpDts $Dtb
if ($LASTEXITCODE -ne 0) {
    Stop-WithMessage "dtc failed while decompiling the DTB."
}

Write-Host ""
Write-Host "[5/6] Patching DTS..."

$s = Get-Content -Raw -LiteralPath $tmpDts

# cpu0-opp-table: allow up to 1.4 V.
$s = Replace-First `
    -Text $s `
    -Pattern '(cpu0-opp-table\s*\{.*?rockchip,max-volt\s*=\s*)<[^;]+>;' `
    -Replacement '${1}<0x155cc0>;' `
    -Label 'cpu0-opp-table rockchip,max-volt'

# CPU regulator vdd_arm / DCDC_REG2: allow up to 1.4 V.
# This is intentionally done by editing the DCDC_REG2 node itself,
# without assuming any specific property order inside that node.
$s = Replace-Property-In-Node `
    -Text $s `
    -NodeName "DCDC_REG2" `
    -PropertyName "regulator-max-microvolt" `
    -NewValue "<0x155cc0>" `
    -Label "DCDC_REG2/vdd_arm regulator-max-microvolt"

# CPU OPPs.
# 1368 MHz stays at 1.35 V.
# 1416 MHz and above use 1.40 V.
# The L0/L1/L2/L3 voltage selectors are intentionally kept uniform.
$s = Normalize-Or-Add-Opp -Text $s -Freq 1368000000 -Uv 1350000 -AnchorFreq 1296000000
$s = Normalize-Or-Add-Opp -Text $s -Freq 1416000000 -Uv 1400000 -AnchorFreq 1368000000
$s = Normalize-Or-Add-Opp -Text $s -Freq 1440000000 -Uv 1400000 -AnchorFreq 1416000000
$s = Normalize-Or-Add-Opp -Text $s -Freq 1464000000 -Uv 1400000 -AnchorFreq 1440000000
$s = Normalize-Or-Add-Opp -Text $s -Freq 1488000000 -Uv 1400000 -AnchorFreq 1464000000
$s = Normalize-Or-Add-Opp -Text $s -Freq 1512000000 -Uv 1400000 -AnchorFreq 1488000000

Set-Content -LiteralPath $tmpDts -Value $s -NoNewline

Assert-Patched-Dts -Text $s

Write-Host ""
Write-Host "[6/6] Recompiling patched DTB and installing Image.oc..."

& $Dtc -I dts -O dtb -o $tmpDtb $tmpDts
if ($LASTEXITCODE -ne 0) {
    Write-Host "dtc failed while recompiling the patched DTB."
    Write-Host "The original files were not modified, except for backups."
    exit 1
}

# Verify the final binary DTB after recompilation.
& $Dtc -I dtb -O dts -o $checkDts $tmpDtb
if ($LASTEXITCODE -ne 0) {
    Write-Host "dtc failed while verifying the patched DTB."
    Write-Host "The original files were not modified, except for backups."
    exit 1
}

$checkText = Get-Content -Raw -LiteralPath $checkDts
Assert-Patched-Dts -Text $checkText

Copy-Item -LiteralPath $tmpDtb -Destination $Dtb -Force
Copy-Item -LiteralPath $ImageOc -Destination $Image -Force

Write-Host ""
Write-Host "Installation complete."
Write-Host ""
Write-Host "Backups:"
Write-Host "  rk3326-r36s-linux.dtb.original"
Write-Host "  Image.original"
Write-Host ""
Write-Host "Patched files:"
Write-Host "  rk3326-r36s-linux.dtb"
Write-Host "  Image"
Write-Host ""
Write-Host "Recommended boot.ini test parameters:"
Write-Host "  max_cpufreq=1368 cpufreq.default_governor=powersave"
Write-Host ""
Write-Host "Temporary DTS kept for inspection:"
Write-Host "  $tmpDts"
Write-Host ""
Write-Host "Verification DTS kept for inspection:"
Write-Host "  $checkDts"
Write-Host ""
Write-Host "To verify the patched DTB manually:"
Write-Host "  dtc.exe -I dtb -O dts rk3326-r36s-linux.dtb > check.dts"
Write-Host ""

exit 0
