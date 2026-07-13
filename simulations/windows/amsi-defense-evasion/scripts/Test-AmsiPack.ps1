[CmdletBinding()]
param(
    [string]$ModuleRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()

$required = @(
    'README.md',
    'THIRD_PARTY_NOTICES.md',
    'atomics\T1685\T1685.yaml',
    'detections\expected-telemetry.md',
    'detections\hunting-guide.md',
    'detections\sigma\proc_creation_win_powershell_amsi_reflection.yml',
    'detections\sigma\registry_set_win_amsi_enable_tampering.yml',
    'scripts\Collect-AmsiTelemetry.ps1',
    'scripts\Invoke-AmsiCanary.ps1',
    'scripts\Run-AmsiSimulation.ps1',
    'scripts\Test-AmsiPack.ps1'
)

foreach ($relative in $required) {
    if (-not (Test-Path (Join-Path $ModuleRoot $relative))) {
        $errors.Add("Missing required file: $relative")
    }
}

$yamlPath = Join-Path $ModuleRoot 'atomics\T1685\T1685.yaml'
if (Test-Path $yamlPath) {
    $yamlText = Get-Content $yamlPath -Raw
    $guidMatches = [regex]::Matches($yamlText, '(?m)^\s*auto_generated_guid:\s*([0-9a-fA-F-]{36})\s*$')
    if ($guidMatches.Count -lt 5) {
        $errors.Add("Expected at least 5 Atomic GUIDs, found $($guidMatches.Count).")
    }

    $guids = foreach ($match in $guidMatches) {
        $value = $match.Groups[1].Value
        $parsed = [Guid]::Empty
        if (-not [Guid]::TryParse($value, [ref]$parsed)) {
            $errors.Add("Invalid GUID: $value")
        }
        $value.ToLowerInvariant()
    }

    foreach ($duplicate in ($guids | Group-Object | Where-Object Count -gt 1)) {
        $errors.Add("Duplicate GUID: $($duplicate.Name)")
    }

    if ($yamlText.Contains([char]0x2014) -or $yamlText.Contains([char]0x2013)) {
        $errors.Add('Atomic YAML contains a long dash character.')
    }

    if (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue) {
        try {
            $parsedYaml = $yamlText | ConvertFrom-Yaml
            if ($null -eq $parsedYaml.atomic_tests) {
                $errors.Add('Parsed YAML has no atomic_tests collection.')
            }
        }
        catch {
            $errors.Add("YAML parser error: $($_.Exception.Message)")
        }
    }
}

foreach ($script in (Get-ChildItem (Join-Path $ModuleRoot 'scripts') -Filter '*.ps1' -File)) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $script.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    )
    foreach ($parseError in $parseErrors) {
        $errors.Add("$($script.Name): $($parseError.Message)")
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    throw "AMSI pack validation failed with $($errors.Count) error(s)."
}

Write-Output 'AMSI pack validation passed.'
