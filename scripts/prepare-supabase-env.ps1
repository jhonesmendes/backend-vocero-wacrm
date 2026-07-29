param(
  [Parameter(Mandatory = $true)]
  [string]$Domain,
  [Parameter(Mandatory = $true)]
  [string]$SiteUrl
)

$ErrorActionPreference = 'Stop'

function New-Hex([int]$Bytes) {
  $buffer = New-Object byte[] $Bytes
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($buffer) } finally { $rng.Dispose() }
  return [BitConverter]::ToString($buffer).Replace('-', '').ToLowerInvariant()
}

function New-Base64Url([byte[]]$Bytes) {
  return [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function New-Base64Secret([int]$Bytes) {
  $buffer = New-Object byte[] $Bytes
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($buffer) } finally { $rng.Dispose() }
  return [Convert]::ToBase64String($buffer)
}

function New-Jwt([string]$Role, [string]$Secret) {
  $header = New-Base64Url ([Text.Encoding]::UTF8.GetBytes('{"alg":"HS256","typ":"JWT"}'))
  $expiry = [DateTimeOffset]::UtcNow.AddYears(10).ToUnixTimeSeconds()
  $payload = New-Base64Url ([Text.Encoding]::UTF8.GetBytes("{`"role`":`"$Role`",`"iss`":`"supabase`",`"iat`":$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()),`"exp`":$expiry}"))
  $hmac = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($Secret))
  try { $signature = New-Base64Url ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes("$header.$payload"))) } finally { $hmac.Dispose() }
  return "$header.$payload.$signature"
}

$root = Split-Path -Parent $PSScriptRoot
$template = Join-Path $root 'infra\supabase\.env.example'
$output = Join-Path $root 'infra\supabase\.env'
if (Test-Path $output) { throw "$output já existe; ele não foi sobrescrito." }

$jwtSecret = New-Base64Secret 48
# Esta senha é interpolada em URLs postgres:// e ecto:// pelos serviços
# Supabase. Use hexadecimal (sem /, +, @ ou :) para não invalidar a URL.
$postgresPassword = New-Hex 32
$values = @{
  'POSTGRES_PASSWORD' = $postgresPassword
  'JWT_SECRET' = $jwtSecret
  'ANON_KEY' = New-Jwt 'anon' $jwtSecret
  'SERVICE_ROLE_KEY' = New-Jwt 'service_role' $jwtSecret
  'DASHBOARD_PASSWORD' = New-Base64Secret 24
  'SECRET_KEY_BASE' = New-Base64Secret 48
  'REALTIME_DB_ENC_KEY' = New-Hex 8
  'VAULT_ENC_KEY' = New-Hex 16
  'PG_META_CRYPTO_KEY' = New-Base64Secret 24
  'LOGFLARE_PUBLIC_ACCESS_TOKEN' = New-Base64Secret 24
  'LOGFLARE_PRIVATE_ACCESS_TOKEN' = New-Base64Secret 24
  'S3_PROTOCOL_ACCESS_KEY_ID' = New-Hex 16
  'S3_PROTOCOL_ACCESS_KEY_SECRET' = New-Hex 32
  'SUPABASE_PUBLIC_URL' = "https://$Domain"
  'API_EXTERNAL_URL' = "https://$Domain/auth/v1"
  'SITE_URL' = $SiteUrl
  'ADDITIONAL_REDIRECT_URLS' = $SiteUrl
  'POOLER_TENANT_ID' = (New-Hex 8)
  'PROXY_DOMAIN' = $Domain
}

$content = Get-Content $template | ForEach-Object {
  if ($_ -match '^([A-Z0-9_]+)=') {
    $key = $Matches[1]
    if ($values.ContainsKey($key)) { return "$key=$($values[$key])" }
  }
  return $_
}
[IO.File]::WriteAllLines($output, $content)

Write-Host "Criado: $output"
Write-Host "Copie para .env.docker:"
Write-Host "  NEXT_PUBLIC_SUPABASE_ANON_KEY=$($values['ANON_KEY'])"
Write-Host "  SUPABASE_SERVICE_ROLE_KEY=$($values['SERVICE_ROLE_KEY'])"
Write-Host "  POSTGRES_PASSWORD=$postgresPassword"
