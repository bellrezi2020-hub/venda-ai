# VendaAI — instalação

Este pacote transforma o protótipo em um MVP com:

- login
- banco online
- contas separadas por imobiliária
- cadastro da empresa
- catálogo de imóveis
- leads com Quente/Morno/Frio
- match de imóveis
- ficha individual do lead
- status comercial
- observações
- conversa contínua com IA
- follow-ups
- dashboard
- página de planos

## 1. Suba estes arquivos para o mesmo repositório `venda-ai`

Mantenha a variável de ambiente da Vercel:

`GEMINI_API_KEY`

Nunca coloque a chave do Gemini no GitHub.

## 2. Crie um projeto no Supabase

No Supabase, abra o SQL Editor e rode o conteúdo de `supabase-schema.sql`.

Depois abra Project Settings > API e copie:

- Project URL
- anon/public key

Abra `config.js` no GitHub e troque:

`COLE_SUA_SUPABASE_URL`

e

`COLE_SUA_SUPABASE_ANON_KEY`

pelos valores do Supabase.

A chave anon é pública e pode ficar no navegador. A chave service_role NÃO pode.

## 3. Autenticação

No Supabase, em Authentication, você pode deixar login por e-mail/senha.

Se a confirmação de e-mail estiver ativa, a pessoa precisa confirmar o e-mail antes de entrar.

## 4. Vercel

A Vercel já está ligada ao GitHub. Depois dos commits, ela publica automaticamente.

## 5. Ordem para testar

1. `login.html` → criar conta
2. `empresa.html` → cadastrar empresa
3. `imoveis.html` → cadastrar imóveis
4. `leads.html` → analisar um lead
5. clicar no lead → abrir `lead.html`
6. testar conversa contínua
7. testar `followups.html`

## Importante

A página `planos.html` é apenas visual. Cobrança real ainda não está ligada.

Como o criador do projeto tem 15 anos, a cobrança/conta de pagamentos precisa ser organizada com um responsável legal antes de vender.
