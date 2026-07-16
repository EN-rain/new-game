param(
    [string]$GodotExe = $env:GODOT_DOTNET_EXE,
    [switch]$SkipExport
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$gameRoot = Join-Path $repoRoot 'game'

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
    throw 'Pass -GodotExe or set GODOT_DOTNET_EXE to the Godot 4.6.2 .NET editor.'
}
if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot .NET editor not found: $GodotExe"
}

$consoleExe = $GodotExe -replace '\.exe$', '_console.exe'
if (-not (Test-Path -LiteralPath $consoleExe)) {
    $consoleExe = $GodotExe
}

Push-Location $repoRoot
try {
    dotnet restore game\NewGame.csproj
    if ($LASTEXITCODE -ne 0) { throw 'Godot project restore failed.' }
    dotnet restore game\tests-csharp\Unit\Oozeborne.UnitTests.csproj --locked-mode
    if ($LASTEXITCODE -ne 0) { throw 'Locked test restore failed.' }
    dotnet build game\NewGame.csproj -c Debug --no-restore
    if ($LASTEXITCODE -ne 0) { throw 'Debug build failed.' }
    dotnet build game\NewGame.csproj -c Release --no-restore
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed.' }
    dotnet test game\tests-csharp\Unit\Oozeborne.UnitTests.csproj -c Debug --no-restore
    if ($LASTEXITCODE -ne 0) { throw 'Unit tests failed.' }

    & $consoleExe --headless --path $gameRoot --scene res://tests-csharp/Integration/m0_interop_test.tscn
    if ($LASTEXITCODE -ne 0) { throw 'Godot M0 interop test failed.' }

    if (-not $SkipExport) {
        $exportDirectory = Join-Path $repoRoot 'exports\M0'
        New-Item -ItemType Directory -Path $exportDirectory -Force | Out-Null
        $exports = @(
            @{ Name = 'Debug'; Path = Join-Path $exportDirectory 'NewGame.Debug.exe'; Flag = '--export-debug' },
            @{ Name = 'Release'; Path = Join-Path $exportDirectory 'NewGame.exe'; Flag = '--export-release' }
        )

        foreach ($export in $exports) {
            & $consoleExe --quiet --headless --path $gameRoot $export.Flag 'Windows Desktop' $export.Path
            if ($LASTEXITCODE -ne 0) { throw "Windows $($export.Name) export failed." }

            $launchLog = Join-Path $exportDirectory "m0-$($export.Name.ToLowerInvariant())-launch.log"
            $process = Start-Process -FilePath $export.Path -ArgumentList @('--log-file', $launchLog) -WindowStyle Hidden -PassThru
            try {
                if ($process.WaitForExit(5000)) {
                    $log = if (Test-Path -LiteralPath $launchLog) { Get-Content -Raw -LiteralPath $launchLog } else { '' }
                    throw "Exported Windows $($export.Name) client exited before the five-second launch gate (code $($process.ExitCode)).`n$log"
                }
            }
            finally {
                if (-not $process.HasExited) {
                    Stop-Process -Id $process.Id -Force
                    $process.WaitForExit()
                }
            }
        }
    }
}
finally {
    Pop-Location
}
