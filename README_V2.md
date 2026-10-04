# VendaAI V2

Incluído nesta versão:
- fluxo de visita: aguardando confirmação -> visita marcada
- editar imóveis
- importação CSV
- painel de pendências
- recuperação de senha
- filtros de leads
- equipe e atribuição de leads (estrutura)
- follow-up por IA
- página de integrações
- base de webhook WhatsApp
- página de planos
- melhorias mobile

## Antes de testar
1. Suba todos os arquivos no GitHub.
2. Rode `supabase-migration-v2.sql` no SQL Editor do Supabase.
3. Mantenha `GEMINI_API_KEY` na Vercel.
4. Mantenha `config.js` com a URL e a Publishable Key do Supabase.

## Integrações externas
WhatsApp, agenda automática e cobrança real precisam de credenciais e provedores externos. A estrutura foi preparada, mas não ficam realmente conectados sem essas credenciais.

## Pagamentos
Como o criador tem 15 anos, cobrança real deve ser configurada com um responsável legal.
