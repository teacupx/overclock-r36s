@echo off
setlocal

REM ============================================================
REM Instalador de overclock para R36S / RK3326 en Windows
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
echo Instalador de overclock para R36S / RK3326
echo ============================================================
echo.

REM Extrae de este mismo BAT el bloque PowerShell incorporado.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$self=$env:SELF; $out=$env:PS1TEMP; $lines=Get-Content -LiteralPath $self; $marker='### POWERSHELL_PAYLOAD_BEGIN'; $idx=[Array]::IndexOf($lines,$marker); if($idx -lt 0){Write-Host 'ERROR: no se ha encontrado el marcador del bloque PowerShell.'; exit 1}; $payload=$lines[($idx+1)..($lines.Count-1)] -join [Environment]::NewLine; Set-Content -LiteralPath $out -Value $payload -Encoding UTF8"

if errorlevel 1 (
    echo ERROR: no se ha podido extraer el bloque PowerShell incorporado.
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
    echo La instalacion ha fallado con codigo de error %ERR%.
    pause
    exit /b %ERR%
)

echo Hecho.
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
        Stop-WithMessage "No se ha podido aplicar el cambio: $Label"
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
        Stop-WithMessage "No se ha encontrado el nodo: $NodeName"
    }

    $node = $range.Node

    $pattern = "($([regex]::Escape($PropertyName))\s*=\s*)<[^;]+>;"
    $replacement = '${1}' + $NewValue + ';'

    $rx = [regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $m = $rx.Match($node)

    if (-not $m.Success) {
        Stop-WithMessage "No se ha encontrado la propiedad $PropertyName dentro del nodo $NodeName ($Label)"
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
        Stop-WithMessage "No se ha encontrado el ancla $anchorName para insertar $name"
    }

    return $Text.Substring(0, $anchor.End) + "`r`n" + (Opp-Block -Freq $Freq -Uv $Uv) + $Text.Substring($anchor.End)
}

function Assert-Patched-Dts {
    param([string]$Text)

    $cpuOpp = Find-NodeRange -Text $Text -NodeName "cpu0-opp-table"
    if ($null -eq $cpuOpp) {
        Stop-WithMessage "La verificacion ha fallado: no se ha encontrado cpu0-opp-table."
    }

    if ($cpuOpp.Node -notmatch 'rockchip,max-volt\s*=\s*<0x155cc0>;') {
        Stop-WithMessage "La verificacion ha fallado: rockchip,max-volt de cpu0-opp-table no es 1400000 uV."
    }

    $dcdc = Find-NodeRange -Text $Text -NodeName "DCDC_REG2"
    if ($null -eq $dcdc) {
        Stop-WithMessage "La verificacion ha fallado: no se ha encontrado DCDC_REG2."
    }

    if ($dcdc.Node -notmatch 'regulator-max-microvolt\s*=\s*<0x155cc0>;') {
        Stop-WithMessage "La verificacion ha fallado: regulator-max-microvolt de DCDC_REG2 no es 1400000 uV."
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
            Stop-WithMessage "La verificacion ha fallado: no se ha encontrado opp-$freq."
        }

        if ($node.Node -notmatch "opp-microvolt\s*=\s*<0x$uvHex 0x$uvHex 0x$uvHex>;") {
            Stop-WithMessage "La verificacion ha fallado: el voltaje objetivo de opp-$freq no es $uv uV."
        }
    }

    Write-Host "Verificacion del DTS correcta."
}

Write-Host "[1/6] Comprobando archivos necesarios..."

if (-not (Test-Path -LiteralPath $Dtc)) {
    Stop-WithMessage "No se ha encontrado dtc.exe en esta carpeta."
}

if (-not (Test-Path -LiteralPath $Dtb)) {
    Stop-WithMessage "No se ha encontrado rk3326-r36s-linux.dtb en esta carpeta."
}

if (-not (Test-Path -LiteralPath $Image)) {
    Stop-WithMessage "No se ha encontrado Image en esta carpeta."
}

if (-not (Test-Path -LiteralPath $ImageOc)) {
    Stop-WithMessage "No se ha encontrado Image.oc en esta carpeta."
}

Write-Host ""
Write-Host "[2/6] Haciendo copia de seguridad del DTB..."

if (Test-Path -LiteralPath $DtbBackup) {
    Write-Host "Ya existe la copia de seguridad: rk3326-r36s-linux.dtb.original"
    Write-Host "Se conserva la copia existente."
} else {
    Copy-Item -LiteralPath $Dtb -Destination $DtbBackup -Force
    Write-Host "Creado: rk3326-r36s-linux.dtb.original"
}

Write-Host ""
Write-Host "[3/6] Haciendo copia de seguridad de Image..."

if (Test-Path -LiteralPath $ImageBackup) {
    Write-Host "Ya existe la copia de seguridad: Image.original"
    Write-Host "Se conserva la copia existente."
} else {
    Copy-Item -LiteralPath $Image -Destination $ImageBackup -Force
    Write-Host "Creado: Image.original"
}

$tmpDts = Join-Path $env:TEMP ("r36s_dtb_patch_" + [System.Guid]::NewGuid().ToString("N") + ".dts")
$tmpDtb = Join-Path $env:TEMP ("r36s_dtb_patch_" + [System.Guid]::NewGuid().ToString("N") + ".dtb")
$checkDts = Join-Path $env:TEMP ("r36s_dtb_check_" + [System.Guid]::NewGuid().ToString("N") + ".dts")

Write-Host ""
Write-Host "[4/6] Descompilando el DTB..."

& $Dtc -I dtb -O dts -o $tmpDts $Dtb
if ($LASTEXITCODE -ne 0) {
    Stop-WithMessage "dtc ha fallado al descompilar el DTB."
}

Write-Host ""
Write-Host "[5/6] Parcheando el DTS..."

$s = Get-Content -Raw -LiteralPath $tmpDts

# cpu0-opp-table: permitir hasta 1,4 V.
$s = Replace-First `
    -Text $s `
    -Pattern '(cpu0-opp-table\s*\{.*?rockchip,max-volt\s*=\s*)<[^;]+>;' `
    -Replacement '${1}<0x155cc0>;' `
    -Label 'cpu0-opp-table rockchip,max-volt'

# Regulador de CPU vdd_arm / DCDC_REG2: permitir hasta 1,4 V.
# Esto se hace editando directamente el nodo DCDC_REG2,
# sin suponer ningun orden concreto de propiedades dentro de ese nodo.
$s = Replace-Property-In-Node `
    -Text $s `
    -NodeName "DCDC_REG2" `
    -PropertyName "regulator-max-microvolt" `
    -NewValue "<0x155cc0>" `
    -Label "DCDC_REG2/vdd_arm regulator-max-microvolt"

# OPP de CPU.
# 1368 MHz se mantiene a 1,35 V.
# 1416 MHz y superiores usan 1,40 V.
# Los selectores de voltaje L0/L1/L2/L3 se mantienen intencionadamente uniformes.
$s = Normalize-Or-Add-Opp -Text $s -Freq 1368000000 -Uv 1350000 -AnchorFreq 1296000000
$s = Normalize-Or-Add-Opp -Text $s -Freq 1416000000 -Uv 1400000 -AnchorFreq 1368000000
$s = Normalize-Or-Add-Opp -Text $s -Freq 1440000000 -Uv 1400000 -AnchorFreq 1416000000
$s = Normalize-Or-Add-Opp -Text $s -Freq 1464000000 -Uv 1400000 -AnchorFreq 1440000000
$s = Normalize-Or-Add-Opp -Text $s -Freq 1488000000 -Uv 1400000 -AnchorFreq 1464000000
$s = Normalize-Or-Add-Opp -Text $s -Freq 1512000000 -Uv 1400000 -AnchorFreq 1488000000

Set-Content -LiteralPath $tmpDts -Value $s -NoNewline

Assert-Patched-Dts -Text $s

Write-Host ""
Write-Host "[6/6] Recompilando el DTB parcheado e instalando Image.oc..."

& $Dtc -I dts -O dtb -o $tmpDtb $tmpDts
if ($LASTEXITCODE -ne 0) {
    Write-Host "dtc ha fallado al recompilar el DTB parcheado."
    Write-Host "Los archivos originales no han sido modificados, salvo las copias de seguridad."
    exit 1
}

# Verifica el DTB binario final despues de recompilar.
& $Dtc -I dtb -O dts -o $checkDts $tmpDtb
if ($LASTEXITCODE -ne 0) {
    Write-Host "dtc ha fallado al verificar el DTB parcheado."
    Write-Host "Los archivos originales no han sido modificados, salvo las copias de seguridad."
    exit 1
}

$checkText = Get-Content -Raw -LiteralPath $checkDts
Assert-Patched-Dts -Text $checkText

Copy-Item -LiteralPath $tmpDtb -Destination $Dtb -Force
Copy-Item -LiteralPath $ImageOc -Destination $Image -Force

Write-Host ""
Write-Host "Instalacion completada."
Write-Host ""
Write-Host "Copias de seguridad:"
Write-Host "  rk3326-r36s-linux.dtb.original"
Write-Host "  Image.original"
Write-Host ""
Write-Host "Archivos parcheados:"
Write-Host "  rk3326-r36s-linux.dtb"
Write-Host "  Image"
Write-Host ""
Write-Host "Parametros recomendados para probar en boot.ini:"
Write-Host "  max_cpufreq=1368 cpufreq.default_governor=powersave"
Write-Host ""
Write-Host "DTS temporal conservado para inspeccion:"
Write-Host "  $tmpDts"
Write-Host ""
Write-Host "DTS de verificacion conservado para inspeccion:"
Write-Host "  $checkDts"
Write-Host ""
Write-Host "Para verificar manualmente el DTB parcheado:"
Write-Host "  dtc.exe -I dtb -O dts rk3326-r36s-linux.dtb > check.dts"
Write-Host ""

exit 0
