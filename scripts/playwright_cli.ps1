$ErrorActionPreference = 'Stop'

# Keep Playwright's workspace identity stable across Codex task directories.
$callerDirectory = (Get-Location).Path
$skillDirectory = Split-Path -Parent $PSScriptRoot
$cliArguments = @($args)
for ($i = 0; $i -lt $cliArguments.Count; $i++) {
    if ($cliArguments[$i] -match '^--filename=(.+)$') {
        $filename = $Matches[1].Trim('"')
        if (-not [System.IO.Path]::IsPathRooted($filename)) {
            $cliArguments[$i] = '--filename=' + [System.IO.Path]::GetFullPath((Join-Path $callerDirectory $filename))
        }
    } elseif ($cliArguments[$i] -eq '--filename' -and ($i + 1) -lt $cliArguments.Count) {
        $filename = $cliArguments[$i + 1].Trim('"')
        if (-not [System.IO.Path]::IsPathRooted($filename)) {
            $cliArguments[$i + 1] = [System.IO.Path]::GetFullPath((Join-Path $callerDirectory $filename))
        }
        $i++
    }
}

$node = Get-Command 'node' -ErrorAction SilentlyContinue
if (-not $node) { throw 'Node.js was not found. Install Node.js/npm to use the Playwright skill.' }

$exitCode = 0
Push-Location -LiteralPath $skillDirectory
try {
    $globalCli = Get-Command 'playwright-cli' -ErrorAction SilentlyContinue
    if ($globalCli) {
        & $globalCli.Source -s=default @cliArguments
        $exitCode = $LASTEXITCODE
    } else {
        $cacheRoot = Join-Path $env:LOCALAPPDATA 'npm-cache\_npx'
        $cliScript = Get-ChildItem -LiteralPath $cacheRoot -Filter 'playwright-cli.js' -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '\\node_modules\\@playwright\\cli\\playwright-cli\.js$' } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1 -ExpandProperty FullName

        if ($cliScript) {
            & $node.Source $cliScript -s=default @cliArguments
            $exitCode = $LASTEXITCODE
        } else {
            $npx = Get-Command 'npx.cmd' -ErrorAction SilentlyContinue
            if (-not $npx) { throw 'Playwright CLI is not installed and npx was not found.' }
            & $npx.Source --yes --package @playwright/cli playwright-cli -s=default @cliArguments
            $exitCode = $LASTEXITCODE
        }
    }
} finally {
    Pop-Location
}
exit $exitCode
