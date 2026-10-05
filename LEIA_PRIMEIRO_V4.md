# VendaAI V4

Este patch fecha o que dá para deixar pronto agora sem novas credenciais externas:

- permissões de administrador x corretor;
- corretor vê apenas leads atribuídos a ele;
- administrador mantém empresa, imóveis, equipe e configurações;
- APIs de IA exigem sessão autenticada;
- adicionar membro exige que o solicitante seja o dono da empresa;
- fluxo de visita continua com confirmação manual;
- checklist final de demonstração.

## Instalação
1. Não substitua `config.js`.
2. Suba os arquivos deste ZIP no GitHub.
3. Rode `supabase-migration-v4.sql` no Supabase SQL Editor.
4. Espere o deploy da Vercel e faça Ctrl+F5.
5. Siga `TESTE_FINAL_V4.md`.

## Vercel
Mantenha:
- GEMINI_API_KEY
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY

Nunca coloque `SUPABASE_SERVICE_ROLE_KEY` no GitHub.

## Ainda depende de serviço externo
- WhatsApp real;
- calendário real;
- pagamentos reais.
