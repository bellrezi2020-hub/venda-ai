export default async function handler(req, res) {

  if (req.method !== "POST") {
    return res.status(405).json({
      erro: "Método não permitido"
    });
  }


  try {

    const {
      nome,
      mensagem,
      negocio,
      empresa
    } = req.body;


    if (!mensagem || !mensagem.trim()) {

      return res.status(400).json({
        erro: "Mensagem não informada."
      });

    }


    const prompt = `
Você é um vendedor especialista em qualificação de leads.

Seu objetivo é ajudar a empresa a converter o cliente,
mas você NUNCA pode inventar informações que a empresa
não forneceu.

========================
EMPRESA
========================

Nome:
${empresa?.nome || "Não informado"}

Tipo de negócio:
${negocio || "Não informado"}

Região atendida:
${empresa?.regiao || "Não informado"}

Produtos ou serviços:
${empresa?.servicos || "Não informado"}

Faixa de preços:
${empresa?.precos || "Não informado"}

Diferenciais:
${empresa?.diferenciais || "Não informado"}

Observações:
${empresa?.observacoes || "Não informado"}


========================
CLIENTE
========================

Nome:
${nome || "Cliente"}

Mensagem:
${mensagem}


========================
SUA TAREFA
========================

Analise a intenção comercial desse cliente.

Classifique o lead apenas como:

Quente
Morno
Frio


Use estas regras:

QUENTE:
cliente demonstra intenção clara de comprar,
contratar, alugar, agendar ou tomar uma decisão em breve.

MORNO:
cliente demonstra interesse real,
mas ainda está pesquisando, comparando ou sem prazo definido.

FRIO:
cliente demonstra pouca intenção comercial,
está apenas curioso ou pesquisando sem intenção clara.


Crie:

1. status
2. intencao
3. resposta
4. proximoPasso


Na resposta ao cliente:

- use as informações reais da empresa quando forem relevantes
- não diga que existe um produto, imóvel ou serviço específico
  se isso não estiver informado
- não invente preços
- não invente disponibilidade
- não invente promoções
- não prometa algo que a empresa não informou
- faça perguntas inteligentes quando faltar informação
- seja comercial, natural e objetivo
- responda em português do Brasil
`;


    const resposta =
      await fetch(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent",
        {

          method: "POST",

          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key":
              process.env.GEMINI_API_KEY
          },

          body: JSON.stringify({

            contents: [
              {
                parts: [
                  {
                    text: prompt
                  }
                ]
              }
            ],

            generationConfig: {

              responseMimeType:
                "application/json",

              responseSchema: {

                type: "OBJECT",

                properties: {

                  status: {
                    type: "STRING"
                  },

                  intencao: {
                    type: "STRING"
                  },

                  resposta: {
                    type: "STRING"
                  },

                  proximoPasso: {
                    type: "STRING"
                  }

                },

                required: [
                  "status",
                  "intencao",
                  "resposta",
                  "proximoPasso"
                ]

              }

            }

          })

        }
      );


    const dados =
      await resposta.json();


    if (!resposta.ok) {

      console.error(dados);

      return res.status(500).json({
        erro:
          "Erro ao consultar a inteligência artificial."
      });

    }


    const texto =
      dados?.candidates?.[0]
        ?.content?.parts?.[0]?.text;


    if (!texto) {

      return res.status(500).json({
        erro:
          "A IA não retornou uma análise."
      });

    }


    const analise =
      JSON.parse(texto);


    return res.status(200).json({

      status:
        analise.status,

      intencao:
        analise.intencao,

      resposta:
        analise.resposta,

      proximoPasso:
        analise.proximoPasso

    });


  } catch (erro) {

    console.error(erro);

    return res.status(500).json({
      erro:
        "Erro interno no servidor."
    });

  }

}
