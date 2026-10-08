VENDAAI V8 — WHATSAPP PREPARADO

Este pacote deixa a base do WhatsApp Cloud API pronta, mas DESLIGADA.

ARQUIVOS PARA O GITHUB:
- api/whatsapp-webhook.js
- api/whatsapp-send.js
- api/whatsapp-settings.js
- integracoes.html

SQL PARA O SUPABASE:
- supabase-migration-v8-whatsapp.sql

O que já fica pronto:
- endpoint de verificação do webhook;
- validação de assinatura dos eventos recebidos;
- identificação da empresa pelo Phone Number ID;
- criação automática de lead por número de WhatsApp;
- gravação de mensagens recebidas;
- atualização de status de entrega;
- envio de mensagem via endpoint autenticado;
- tela de configuração com IDs não secretos;
- nenhuma chave secreta é gravada no GitHub ou no banco.

O que fica DESLIGADO:
- resposta automática por IA;
- ativação real da conexão.

QUANDO A META LIBERAR:
1. Criar/concluir o app VendaAI e o WhatsApp Cloud API.
2. Na Vercel, criar as variáveis:
   WHATSAPP_ACCESS_TOKEN
   WHATSAPP_VERIFY_TOKEN
   META_APP_SECRET
   META_GRAPH_VERSION
3. NÃO mandar os valores dessas variáveis no chat.
4. Na tela Integrações do VendaAI, preencher:
   Phone Number ID
   WABA ID
   número exibido
5. Na Meta, cadastrar o webhook:
   https://SEU-DOMINIO/api/whatsapp-webhook
6. Usar o mesmo WHATSAPP_VERIFY_TOKEN definido na Vercel.
7. Assinar o campo de mensagens no painel da Meta.
8. Só depois marcar "Ativar WhatsApp" no VendaAI.

IMPORTANTE:
- O token fica apenas na Vercel.
- Esta primeira versão é adequada para o beta com um número/conta de WhatsApp.
- Para um SaaS multiempresa em escala, cada cliente precisará de credenciais próprias
  armazenadas em infraestrutura segura; não vamos colocar tokens de clientes em HTML.
- A resposta automática por IA será ativada somente após testarmos recebimento e envio
  manual, para evitar mensagens erradas ou consumo acidental de IA.
