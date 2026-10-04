export default async function handler(req, res) {

  if (req.method !== "POST") {
    return res.status(405).json({
      erro: "Método não permitido"
    });
  }

  try {

    const {
      lead,
      empresa,
      imoveis,
      mensagens
    } = req.body;


    const historico = (mensagens || [])
      .map(m => {
        const papel =
          m.role === "assistant"
            ? "ASSISTENTE"
            : "CLIENTE";

        return `${papel}: ${m.content}`;
      })
      .join("\n");


    const catalogo = (imoveis || [])
      .map(i => `
Título: ${i.title}
Finalidade: ${i.purpose}
Tipo: ${i.type}
Preço: R$ ${i.price}
Bairro: ${i.neighborhood || "Não informado"}
Cidade: ${i.city || "Não informado"}
Quartos: ${i.bedrooms || 0}
Garagem: ${i.garage ? "Sim" : "Não"}
Descrição: ${i.description || ""}
`)
      .join("\n");


    const prompt = `
Você é um assistente comercial especialista em vendas imobiliárias.

Você está continuando uma conversa que já começou.

========================
EMPRESA
========================

Nome:
${empresa?.name || "Não informado"}

Região:
${empresa?.region || "Não informado"}

Diferenciais:
${empresa?.differentials || "Não informado"}

Observações:
${empresa?.notes || "Não informado"}


========================
LEAD
========================

Nome:
${lead?.name || "Cliente"}

Temperatura anterior:
${lead?.temperature || "Não informado"}

Intenção anterior:
${lead?.intent || "Não informado"}

Próximo passo anterior:
${lead?.next_step || "Não informado"}


========================
CATÁLOGO REAL
========================

${catalogo || "Nenhum imóvel cadastrado."}


========================
CONVERSA
========================

${historico}


========================
OBJETIVO
========================

Continue a conversa com o cliente.

Você deve:

1. Entender as novas informações dadas pelo cliente.

2. Atualizar a intenção comercial.

3. Atualizar a temperatura do lead.

A temperatura DEVE SER EXATAMENTE UMA destas opções:

"Quente"
"Morno"
"Frio"

NUNCA retorne:
Sucesso
Interessado
Qualificado
Alta
Fechado
Pronto
ou qualquer outro valor.

Use:

QUENTE:
Cliente demonstra intenção clara de comprar,
alugar, visitar, negociar ou tomar decisão em breve.

MORNO:
Cliente tem interesse real,
mas ainda está pesquisando,
comparando ou sem prazo claro.

FRIO:
Cliente tem pouca intenção comercial
ou apenas está pesquisando sem intenção definida.


4. Encontre no máximo 3 imóveis compatíveis.

Use SOMENTE imóveis realmente presentes no catálogo.

Nunca invente imóveis.

5. Crie uma resposta natural para continuar a conversa.

Faça no máximo UMA pergunta por vez.

Não repita perguntas que o cliente já respondeu.

Se o cliente já informou:

- bairro
- orçamento
- quartos
- garagem
- intenção
- prazo

não pergunte novamente.

Se ele informar disponibilidade para visita,
avance para confirmar/agendar a visita.

Não diga que uma visita está confirmada
se ainda não houve confirmação da imobiliária.

Não invente horários disponíveis.

Não invente preços.

Não invente descontos.

Não invente disponibilidade.

Não invente condições de financiamento.

6. Determine o próximo passo comercial.

Responda em português do Brasil.
`;


    const resposta = await fetch(
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
                  type: "STRING",
                  enum: [
                    "Quente",
                    "Morno",
                    "Frio"
                  ]
                },

                intencao: {
                  type: "STRING"
                },

                resposta: {
                  type: "STRING"
                },

                proximoPasso: {
                  type: "STRING"
                },

                imoveisCompativeis: {

                  type: "ARRAY",

                  items: {

                    type: "OBJECT",

                    properties: {

                      titulo: {
                        type: "STRING"
                      },

                      motivo: {
                        type: "STRING"
                      }

                    },

                    required: [
                      "titulo",
                      "motivo"
                    ]

                  }

                }

              },

              required: [
                "status",
                "intencao",
                "resposta",
                "proximoPasso",
                "imoveisCompativeis"
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
          "A IA não retornou resposta."
      });

    }


    const analise =
      JSON.parse(texto);


    const statusPermitidos =
      ["Quente", "Morno", "Frio"];


    if (
      !statusPermitidos.includes(
        analise.status
      )
    ) {

      analise.status =
        lead?.temperature &&
        statusPermitidos.includes(
          lead.temperature
        )
          ? lead.temperature
          : "Morno";

    }


    return res.status(200).json({

      status:
        analise.status,

      intencao:
        analise.intencao,

      resposta:
        analise.resposta,

      proximoPasso:
        analise.proximoPasso,

      imoveisCompativeis:
        analise.imoveisCompativeis || []

    });


  } catch (erro) {

    console.error(erro);

    return res.status(500).json({
      erro:
        "Erro interno no servidor."
    });

  }

}
