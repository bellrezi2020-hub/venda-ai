# Relatório — VendaAI Marketplace V10

## Objetivo desta rodada
Transformar a direção da VendaAI de ferramenta focada apenas em imóveis para uma base de marketplace regional multategoria, preservando o sistema imobiliário/CRM que já existe.

## Decisões aplicadas
- Categorias iniciais: imóveis, veículos, produtos e serviços.
- Qualquer pessoa poderá vender após verificação de segurança.
- Lojas/vendedores terão página própria com catálogo.
- Negociação deve permanecer dentro da VendaAI sempre que possível.
- Propostas e contrapropostas ficam previstas.
- Avaliações públicas e reputação dos dois lados.
- Disputas e denúncias com fila para revisão administrativa.
- Anúncios de risco médio/alto podem ficar em revisão.
- Pagamento futuro com retenção até entrega/confirmação e liberação automática por prazo quando não houver disputa.
- Serviços podem ter agendamento e sinal opcional.
- Carteira futura permite sacar ou reutilizar saldo na VendaAI.
- Planos, comissão, taxa de proteção e patrocinados podem coexistir, mas a cobrança real ainda não foi ativada.
- Programa “100 primeiros vendedores” foi incorporado à página de aquisição.

## O que foi criado agora
1. Nova landing pública orientada a marketplace.
2. Vitrine Marketplace com busca/filtro demonstrativos.
3. Página para captar vendedores/empresas.
4. Página de segurança explicando as camadas de confiança.
5. Página-modelo de loja do vendedor.
6. Página-modelo de anúncio.
7. Protótipo do painel administrativo Marketplace.
8. CSS separado para não quebrar o CRM existente.
9. JavaScript separado com dados de demonstração e função de detecção/ocultação de contatos externos.
10. Migração SQL V10 aditiva com tabelas essenciais de marketplace.

## O que preservei
- `index.html` continua sendo o dashboard do CRM atual.
- `app.js`, `styles.css`, integrações, leads, imóveis, WhatsApp V8 e regras V9 não foram substituídos nesta entrega.
- Nenhuma chave secreta foi adicionada.
- Nenhuma cobrança real foi ativada.

## Pontos que ainda precisam ser feitos
### Prioridade alta
- Conectar cadastro do vendedor ao Supabase.
- Criar fluxo real de verificação de identidade.
- Conectar criação/edição de anúncios e upload de fotos.
- Carregar anúncios reais na vitrine.
- Criar chat/propostas reais.
- Criar painel admin autenticado com permissões.

### Prioridade média
- Favoritos, seguidores e alertas.
- Ranking e “Em alta”.
- “Quero comprar”/pedido de demanda.
- Agendamento de serviços.
- IA de recomendação/busca conversacional.

### Somente depois de estrutura financeira/jurídica
- Split de pagamento.
- Retenção/liberação automática.
- Carteira e saques.
- Taxa de proteção/comissões reais.
- Reembolso/disputa financeira real.
- Garantia opcional/parceiros.

## Observação técnica importante
A migração V10 habilita RLS e começa deliberadamente restritiva. As tabelas financeiras não recebem políticas de escrita pelo navegador: pagamento, carteira e saque devem passar por backend/API server-side e provedor especializado. Isso reduz o risco de alguém adulterar saldo pelo front-end.
