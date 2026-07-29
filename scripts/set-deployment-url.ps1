param(
  [Parameter(Mandatory = $true)]
  [string]$Domain,
  [int]$HttpPort = 80,
  [int]$HttpsPort = 443
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$url = "https://$Domain"

function Set-EnvValue([string]$Path, [string]$Name, [string]$Value) {
  if (-not (Test-Path $Path)) { throw "Não encontrado: $Path" }
  $found = $false
  $content = Get-Content $Path | ForEach-Object {
    if ($_ -match ("^{0}=" -f [regex]::Escape($Name))) {
      if (-not $found) { $found = $true; return "$Name=$Value" }
      return $null
    }
    return $_
  }
  if (-not $found) { $content += "$Name=$Value" }
  [IO.File]::WriteAllLines($Path, @($content | Where-Object { $null -ne $_ }))
}

$appEnv = Join-Path $root '.env.docker'
$supabaseEnv = Join-Path $root 'infra\supabase\.env'

Set-EnvValue $appEnv 'WACRM_DOMAIN' $Domain
Set-EnvValue $appEnv 'WACRM_HTTP_PORT' $HttpPort
Set-EnvValue $appEnv 'WACRM_HTTPS_PORT' $HttpsPort
Set-EnvValue $appEnv 'NEXT_PUBLIC_SITE_URL' $url
Set-EnvValue $appEnv 'NEXT_PUBLIC_SUPABASE_URL' $url
Set-EnvValue $appEnv 'SUPABASE_INTERNAL_URL' 'http://kong:8000'

Set-EnvValue $supabaseEnv 'SUPABASE_PUBLIC_URL' $url
Set-EnvValue $supabaseEnv 'API_EXTERNAL_URL' "$url/auth/v1"
Set-EnvValue $supabaseEnv 'SITE_URL' $url
Set-EnvValue $supabaseEnv 'ADDITIONAL_REDIRECT_URLS' $url
Set-EnvValue $supabaseEnv 'GOTRUE_MAILER_EXTERNAL_HOSTS' $Domain

Write-Host "Configuração preparada para $url"
