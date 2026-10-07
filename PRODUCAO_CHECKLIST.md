# VendaAI - checklist para colocar no ar

## Já preparado por código
- administrador x corretor
- leads atribuídos
- RLS
- APIs autenticadas
- cotas mensais de IA
- limite de tamanho de mensagens
- histórico reduzido enviado à IA
- confirmação humana de visitas
- headers básicos de segurança
- recuperação de senha
- backup JSON

## Você ainda precisa fazer
1. Subir este patch sem substituir `config.js`.
2. Rodar `supabase-migration-v5.sql` no Supabase.
3. Confirmar na Vercel: GEMINI_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
4. Testar conta administradora.
5. Testar conta corretor.
6. Testar IA e visita.
7. Escolher domínio.
8. Escolher WhatsApp.
9. Escolher agenda.
10. Escolher pagamento.
11. Revisar LGPD/Termos.

## O que preciso que você me diga
NÃO mande senhas, tokens ou chaves.

Pode me mandar:
- nome comercial final
- 2 ou 3 opções de domínio
- WhatsApp: Meta Cloud API ou outro
- Agenda: Google Calendar ou outro
- Pagamento: Mercado Pago ou Stripe
- nome/razão social que ficará nos Termos
- e-mail público de suporte
- e-mail público de privacidade
- planos e preços
- limites por plano
