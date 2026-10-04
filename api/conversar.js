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
Você é um assistente comercial de uma imobiliária.

IMPORTANTE:
Você NÃO possui acesso a agenda,
calendário, corretor ou sistema de confirmação.

Portanto:

NUNCA diga que uma visita está confirmada.
NUNCA diga que um horário está reservado.
NUNCA diga que um corretor foi designado.
NUNCA invente endereço.
NUNCA invente contato de corretor.

Se o cliente pedir para marcar uma visita,
você deve dizer que a solicitação será
encaminhada para confirmação pela imobiliária.

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

Intenção:
${lead?.intent || "Não informado"}

========================
CATÁLOGO REAL
========================

${catalogo || "Nenhum imóvel cadastrado."}

========================
CONVERSA
========================

${historico}

========================
TAREFA
========================

Atualize:

status:
somente "Quente", "Morno" ou "Frio"

intencao:
resumo atualizado do objetivo do cliente

resposta:
mensagem natural para enviar ao cliente

proximoPasso:
ação interna da imobiliária

solicitouVisita:
true se o cliente pediu para marcar/agendar visita

imoveisCompativeis:
no máximo 3 imóveis REAIS do catálogo

Se o cliente pedir visita:

A resposta deve seguir esta lógica:

"Perfeito! Vou encaminhar sua preferência
de dia e horário para a imobiliária confirmar
a disponibilidade da visita."

Pode mencionar o imóvel cadastrado,
mas não confirme o horário.

Não invente nenhuma informação.
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

                solicitouVisita: {
                  type: "BOOLEAN"
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
                "solicitouVisita",
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

    const permitidos = [
      "Quente",
      "Morno",
      "Frio"
    ];

    if (
      !permitidos.includes(
        analise.status
      )
    ) {
      analise.status =
        permitidos.includes(
          lead?.temperature
        )
          ? lead.temperature
          : "Morno";
    }

    /*
      PROTEÇÃO EXTRA DO SERVIDOR

      Mesmo que a IA tente confirmar
      uma visita indevidamente,
      substituímos a resposta.
    */

    if (analise.solicitouVisita) {
      const primeiroImovel =
        analise.imoveisCompativeis?.[0]
          ?.titulo;

      analise.resposta =
        primeiroImovel
          ? `Perfeito, ${lead?.name || "Cliente"}! Vou encaminhar sua preferência de dia e horário para a imobiliária confirmar a disponibilidade da visita ao imóvel ${primeiroImovel}. Assim que houver confirmação, você recebe os detalhes.`
          : `Perfeito, ${lead?.name || "Cliente"}! Vou encaminhar sua preferência de dia e horário para a imobiliária confirmar a disponibilidade da visita. Assim que houver confirmação, você recebe os detalhes.`;

      analise.proximoPasso =
        "Confirmar internamente a disponibilidade da visita e depois retornar ao cliente.";
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

      solicitouVisita:
        analise.solicitouVisita,

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
