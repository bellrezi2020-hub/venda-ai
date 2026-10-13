# VendaAI V10 — Fundação Marketplace

Esta atualização NÃO apaga o CRM imobiliário atual. Ela adiciona uma nova frente pública de marketplace e uma fundação de banco para evoluir a VendaAI para produtos, serviços, veículos e imóveis.

## Arquivos para adicionar/substituir

### Substituir
- `landing.html`

### Adicionar
- `marketplace.css`
- `marketplace.js`
- `marketplace.html`
- `vender.html`
- `seguranca.html`
- `loja.html`
- `anuncio.html`
- `painel-marketplace.html`
- `supabase-migration-v10-marketplace.sql`
- `RELATORIO-V10.md`

## O que já funciona visualmente
- Nova landing da VendaAI Marketplace.
- Quatro categorias iniciais: Imóveis, Veículos, Produtos e Serviços.
- Busca e filtros em uma vitrine demonstrativa.
- Página “Venda na VendaAI” com programa dos 100 primeiros.
- Página de loja/vendedor.
- Página de anúncio com compra e proposta previstas dentro da plataforma.
- Página de segurança.
- Protótipo do painel administrativo/filas de risco.

## O que a migração V10 prepara
- Perfis de marketplace e níveis de verificação.
- Lojas.
- Anúncios multcategoria.
- Fotos/mídia.
- Favoritos e seguidores.
- Propostas.
- Conversas e mensagens com sinalizador de contato ocultado.
- Pedidos e retenção/liberação futura de pagamento.
- Carteira contábil.
- Disputas, denúncias e avaliações.
- Reservas/agendamentos com sinal.

## O que NÃO está ligado ainda
- Pagamento real/split.
- Saque/Pix.
- Verificação real de CPF/documento/selfie.
- IA real da busca do marketplace.
- Chat real entre comprador e vendedor.
- Frete.
- Autenticação das novas telas públicas.
- Dados reais na vitrine/painel Marketplace.

Esses itens foram deixados propositalmente sem “fingir” funcionamento, porque dependem de provedor, API server-side, credenciais e/ou decisões jurídicas.

## Instalação sugerida
1. Faça backup/branch do estado atual.
2. Suba os arquivos desta pasta na raiz do repositório.
3. Espere a Vercel publicar.
4. Teste `landing.html`, `marketplace.html`, `vender.html`, `loja.html`, `anuncio.html`, `seguranca.html` e `painel-marketplace.html`.
5. Somente depois, em ambiente de teste, rode `supabase-migration-v10-marketplace.sql`.
6. Não configure pagamentos reais ainda.

## Próxima etapa
Conectar primeiro cadastro de vendedor + anúncios + lojas reais ao Supabase. Depois chat/propostas. Pagamentos e carteira ficam após escolha e validação do provedor.
