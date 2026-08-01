param(
    [ValidateSet('up', 'doctor', 'logs', 'status', 'down', 'reset')]
    [string]$Action = 'up'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Set-Location -LiteralPath $PSScriptRoot

function Invoke-Docker {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & docker @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "docker $($Arguments -join ' ') failed"
    }
}

function Test-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker Desktop is required.'
    }
    Invoke-Docker -Arguments @('info') | Out-Null
    Invoke-Docker -Arguments @('compose', 'version') | Out-Null
    Invoke-Docker -Arguments @('compose', 'config', '-q') | Out-Null
}

function Wait-Demo {
    'Waiting for model preparation and the private devnet...'
    foreach ($attempt in 1..360) {
        & docker compose exec -T demo curl -fsS http://127.0.0.1:8081/ *> $null
        if ($LASTEXITCODE -eq 0) {
            'Keryx image demo: http://127.0.0.1:8080'
            Start-Process 'http://127.0.0.1:8080'
            return
        }

        $exited = & docker compose ps --status exited -q demo
        if ($exited) {
            & docker compose logs --tail=100 demo
            throw 'The demo stopped before becoming ready.'
        }
        Start-Sleep -Seconds 10
    }

    & docker compose logs --tail=100 demo
    throw 'The demo did not become ready within one hour.'
}

switch ($Action) {
    'up' {
        Test-Docker
        New-Item -ItemType Directory -Force -Path (Join-Path $PSScriptRoot 'models') | Out-Null
        Invoke-Docker -Arguments @('compose', 'up', '--build', '--detach')
        Wait-Demo
    }
    'doctor' {
        Test-Docker
        Invoke-Docker -Arguments @('run', '--rm', '--gpus', 'all', 'nvidia/cuda:13.0.1-base-ubuntu24.04', 'nvidia-smi')
    }
    'logs' { Invoke-Docker -Arguments @('compose', 'logs', '--follow', 'demo') }
    'status' { Invoke-Docker -Arguments @('compose', 'ps') }
    'down' { Invoke-Docker -Arguments @('compose', 'down') }
    'reset' {
        Invoke-Docker -Arguments @('compose', 'down', '--volumes', '--remove-orphans')
        'Devnet state reset. Downloaded models were preserved.'
    }
}
