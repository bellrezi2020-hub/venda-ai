VendaAI V3 - melhorias adicionais

Inclui neste patch:
- app.js: membros da equipe também conseguem localizar a empresa
- lead.html: limpar conversa e excluir lead de teste
- configuracoes.html: exportar backup JSON e apagar todos os leads de teste
- landing.html: página pública de apresentação
- privacidade.html: modelo de política de privacidade
- termos.html: modelo de termos de uso
- supabase-migration-v3.sql: reforço de RLS/índices e suporte à equipe

COMO USAR
1. Suba os arquivos deste patch para o mesmo repositório e substitua quando houver arquivo com o mesmo nome.
2. Preserve o seu config.js atual com a URL real e a Publishable Key.
3. Rode supabase-migration-v3.sql no SQL Editor.
4. Dê Ctrl+F5 no site.

O que ainda depende de serviço externo:
- WhatsApp real: precisa escolher/configurar um provedor oficial.
- Agenda automática real: precisa conectar um calendário.
- Pagamento real: precisa provedor de cobrança e responsável legal.
