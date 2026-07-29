param(
  [string]$Domain = 'localhost'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$supabaseEnv = Join-Path $root 'infra\supabase\.env'
$output = Join-Path $root '.env.docker'

if (-not (Test-Path $supabaseEnv)) { throw "Não encontrado: $supabaseEnv. Execute prepare-supabase-env.ps1 primeiro." }
if (Test-Path $output) { throw "$output já existe; ele não foi sobrescrito." }

function Get-EnvValue([string]$Path, [string]$Name) {
  if (-not (Test-Path $Path)) { return '' }
  $line = Get-Content $Path | Where-Object { $_ -match ("^{0}=" -f [regex]::Escape($Name)) } | Select-Object -First 1
  if ($null -eq $line) { return '' }
  return $line.Substring($Name.Length + 1)
}

function New-Hex([int]$Bytes) {
  $buffer = New-Object byte[] $Bytes
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($buffer) } finally { $rng.Dispose() }
  return [BitConverter]::ToString($buffer).Replace('-', '').ToLowerInvariant()
}

$anon = Get-EnvValue $supabaseEnv 'ANON_KEY'
$service = Get-EnvValue $supabaseEnv 'SERVICE_ROLE_KEY'
$postgres = Get-EnvValue $supabaseEnv 'POSTGRES_PASSWORD'
$existingEnv = Join-Path $root '.env'
$metaSecret = Get-EnvValue $existingEnv 'META_APP_SECRET'
$metaAppId = Get-EnvValue $existingEnv 'META_APP_ID'

$scheme = if ($Domain -eq 'localhost') { 'https' } else { 'https' }
$url = "${scheme}://$Domain"
$content = @(
  "WACRM_DOMAIN=$Domain",
  "NEXT_PUBLIC_SITE_URL=$url",
  "NEXT_PUBLIC_SUPABASE_URL=$url",
  "SUPABASE_INTERNAL_URL=http://kong:8000",
  "NEXT_PUBLIC_APP_LOCALE=pt-BR",
  "NEXT_PUBLIC_SUPABASE_ANON_KEY=$anon",
  "SUPABASE_SERVICE_ROLE_KEY=$service",
  "POSTGRES_PASSWORD=$postgres",
  "ENCRYPTION_KEY=$(New-Hex 32)",
  "META_APP_SECRET=$metaSecret",
  "META_APP_ID=$metaAppId",
  "AUTOMATION_CRON_SECRET=$(New-Hex 32)"
)
[IO.File]::WriteAllLines($output, $content)
Write-Host "Criado: $output"
