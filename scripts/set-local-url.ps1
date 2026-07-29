param(
  [int]$HttpsPort = 8443
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$url = "https://localhost:$HttpsPort"

function Set-EnvValue([string]$Path, [string]$Name, [string]$Value) {
  if (-not (Test-Path $Path)) { throw "Não encontrado: $Path" }
  $content = Get-Content $Path | ForEach-Object {
    if ($_ -match ("^{0}=" -f [regex]::Escape($Name))) { return "$Name=$Value" }
    return $_
  }
  [IO.File]::WriteAllLines($Path, $content)
}

$appEnv = Join-Path $root '.env.docker'
$supabaseEnv = Join-Path $root 'infra\supabase\.env'

Set-EnvValue $appEnv 'NEXT_PUBLIC_SITE_URL' $url
Set-EnvValue $appEnv 'NEXT_PUBLIC_SUPABASE_URL' $url
Set-EnvValue $supabaseEnv 'SUPABASE_PUBLIC_URL' $url
Set-EnvValue $supabaseEnv 'API_EXTERNAL_URL' "$url/auth/v1"
Set-EnvValue $supabaseEnv 'SITE_URL' $url
Set-EnvValue $supabaseEnv 'ADDITIONAL_REDIRECT_URLS' $url
# O compose local não inclui um SMTP. Confirmação automática permite criar a
# primeira conta; em produção configure SMTP e mantenha este valor como false.
Set-EnvValue $supabaseEnv 'ENABLE_EMAIL_AUTOCONFIRM' 'true'

Write-Host "URLs locais atualizadas para $url"
