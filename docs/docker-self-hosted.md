# WACRM + Supabase em Docker

Esta configuração mantém a aplicação, banco, autenticação, API REST, Realtime,
Storage e Studio no mesmo servidor Docker. Nenhum dado é enviado ao Supabase Cloud.

## Pré-requisitos

- Docker Engine + Docker Compose
- Um domínio público apontado para o IP do servidor, com as portas 80 e 443 abertas
- Credenciais da Meta para o webhook do WhatsApp

## Instalação inicial

1. Gere os segredos do Supabase uma única vez. Substitua o domínio e a URL pelo
   endereço público final:

   ```powershell
   .\scripts\prepare-supabase-env.ps1 -Domain crm.seudominio.com -SiteUrl https://crm.seudominio.com
   ```

   O script gera a senha do Postgres em hexadecimal, pois ela também é usada
   em URLs de conexão internas do Auth e do Supavisor.

   Para uma VM já preparada, atualize os dois arquivos de ambiente e publique
   as portas padrão com:

   ```powershell
   .\scripts\set-deployment-url.ps1 -Domain pad.jhontisystem.com.br
   ```

2. Gere o ambiente do WACRM com as chaves locais. O script preserva as
   credenciais Meta existentes no `.env`, quando houver:

   ```powershell
   .\scripts\prepare-wacrm-env.ps1 -Domain crm.seudominio.com
   ```

3. Suba a plataforma Supabase. Ela cria a rede interna `wacrm-network`:

   ```powershell
   docker compose --env-file infra/supabase/.env -f infra/supabase/docker-compose.yml up -d
   ```

4. Aplique as migrações do WACRM. Este passo é seguro para repetir e registra as
   migrações já aplicadas:

   ```powershell
   docker compose --env-file .env.docker --profile tools run --rm migrate
   ```

5. Crie a imagem e inicie WACRM e o proxy HTTPS:

   ```powershell
   docker compose --env-file .env.docker up -d --build
   ```

Em desenvolvimento local, acesse `https://localhost:8443`. Em produção, defina
`WACRM_HTTP_PORT=80` e `WACRM_HTTPS_PORT=443`; o Caddy renova os certificados
TLS automaticamente. Configure na Meta o webhook
como `https://crm.seudominio.com/api/whatsapp/webhook`.

## Operação

- CRM e API Supabase pública: `https://crm.seudominio.com`
- Studio: `http://IP_DO_SERVIDOR:8000` não é exposto; para acessá-lo com segurança,
  use temporariamente um proxy autenticado ou uma porta local de administração.
- Dados persistentes: `infra/supabase/volumes/db/data` e
  `infra/supabase/volumes/storage`.
- Backup do banco: execute `pg_dump` dentro do container `supabase-db`; faça também
  backup do diretório de Storage.

Não use `docker compose down -v`: isso remove volumes nomeados do Supabase. Não
apague `infra/supabase/volumes/db/data` nem `infra/supabase/volumes/storage`.
