VENDAAI V7 — SEGURANÇA DO ADMIN

Substitua no GitHub estes 6 arquivos:
- app.js
- empresa.html
- imoveis.html
- equipe.html
- integracoes.html
- configuracoes.html

O que foi corrigido:
1. Páginas exclusivas do administrador agora chamam renderNav() + requireOwner().
2. Corretor que digitar a URL diretamente é redirecionado para o Dashboard.
3. currentCompany() agora prioriza empresa própria antes de vínculo como membro.
4. equipe.html agora envia o token de autenticação para /api/add-member.
5. Operações sensíveis checam a empresa atual e o papel de proprietário no front.
6. Configurações ganhou atalho para Planos.

TESTE APÓS O DEPLOY:
A) Administrador:
- Empresa abre
- Imóveis abre
- Equipe abre
- Integrações abre
- Configurações abre

B) Corretor:
Tente abrir manualmente:
- /empresa.html
- /imoveis.html
- /equipe.html
- /integracoes.html
- /configuracoes.html

Esperado: alerta "Esta área é exclusiva do administrador." e redirecionamento para index.html.

IMPORTANTE:
A proteção principal de dados continua sendo o RLS do Supabase e as APIs autenticadas.
Este pacote também fecha o acesso visual/direto às páginas de administração.
