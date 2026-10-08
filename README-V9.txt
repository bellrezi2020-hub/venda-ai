VENDAAI V9 — FECHAMENTO DA NOITE

ARQUIVOS PARA SUBSTITUIR/ADICIONAR NO GITHUB
- api/_usage.js
- landing.html
- termos.html
- privacidade.html
- planos.html
- vendas.html
- supabase-migration-v9-beta.sql

O QUE ESTA VERSÃO FAZ
1. Corrige a taxa de sucesso:
   - taxa e plano ficam congelados quando a venda nasce;
   - editar o lead depois não recalcula a taxa;
   - mudar de plano não altera venda antiga.

2. Cria status financeiro da venda:
   - pending
   - paid
   - waived
   Pagamentos reais continuam desligados.

3. Cria plano interno DEV para a Imobiliária Prime:
   - IA praticamente ilimitada para testes;
   - limites altos de usuários, imóveis e leads;
   - sem taxa de sucesso;
   - não é plano comercial.

4. Aplica limites reais no banco:
   - usuários;
   - imóveis;
   - leads.
   Mesmo se alguém tentar contornar a interface, o banco bloqueia.

5. Torna consumo de IA atômico:
   - evita corrida entre duas requisições simultâneas.

6. Atualiza a Landing:
   - Pro = R$ 349/mês;
   - Starter = R$ 149/mês;
   - taxas de sucesso corretas;
   - trial de 3 usos;
   - suporte e links jurídicos.

7. Amplia Termos e Privacidade:
   - continuam sendo RASCUNHOS;
   - precisam de revisão jurídica antes de cobrar clientes.

8. Atualiza tela Planos:
   - mostra plano atual;
   - mostra uso quando aplicável;
   - identifica ambiente DEV.

9. Atualiza tela Vendas:
   - mostra plano congelado;
   - mostra status financeiro.

ORDEM PARA INSTALAR
A) Suba os arquivos do ZIP no GitHub.
B) Espere a Vercel publicar.
C) No Supabase SQL Editor, rode TODO o arquivo:
   supabase-migration-v9-beta.sql
D) Atualize o site com Ctrl+F5.

TESTE RÁPIDO
- Abra Configurações > Planos.
- Deve aparecer "Ambiente de desenvolvimento".
- Abra Vendas; as vendas antigas continuam aparecendo.
- Faça um uso de IA; não deve travar por causa dos 3 usos do trial.

IMPORTANTE
- WhatsApp V8 continua separado e depende da Meta para ativação.
- Google Calendar ainda depende de credenciais OAuth do Google.
- Pagamentos continuam desligados.
- Não coloque tokens, service role ou chaves secretas no GitHub.
- A taxa de sucesso vinculada a negócio imobiliário precisa de revisão jurídica/contratual antes de cobrança real.
