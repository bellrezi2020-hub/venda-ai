export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ erro: "Método não permitido" });
  }

  try {
    const { nome, mensagem, negocio } = req.body;

    if (!mensagem || !mensagem.trim()) {
      return res.status(400).json({
        erro: "Mensagem não informada."
      });
    }

    const prompt = `
Você é um vendedor especialista em qualificação de leads.

NEGÓCIO:
${negocio}

CLIENTE:
${nome || "Cliente"}

MENSAGEM:
${mensagem}

Analise a mensagem.

Classifique a temperatura do lead como:
"Frio", "Morno" ou "Quente".

Um lead Quente demonstra intenção clara de comprar, contratar,
agendar ou tomar uma decisão em breve.

Um lead Morno demonstra interesse, mas ainda precisa de informações.

Um lead Frio tem pouca intenção comercial ou está apenas pesquisando.

Crie também:

- intenção: resumo do que o cliente quer
- resposta: melhor mensagem que a empresa deve enviar
- proximoPasso: próxima pergunta ou ação para aproximar a venda

Não invente informações.
Se faltar informação, faça uma pergunta inteligente.
`;

    const resposta = await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent",
      {
        method: "POST",

        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": process.env.GEMINI_API_KEY
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
            responseMimeType: "application/json",

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

    const dados = await resposta.json();

    if (!resposta.ok) {
      console.error(dados);

      return res.status(500).json({
        erro: "Erro ao consultar a inteligência artificial."
      });
    }

    const texto =
      dados?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!texto) {
      return res.status(500).json({
        erro: "A IA não retornou uma análise."
      });
    }

    const analise = JSON.parse(texto);

    return res.status(200).json({
      status: analise.status,
      intencao: analise.intencao,
      resposta: analise.resposta,
      proximoPasso: analise.proximoPasso
    });

  } catch (erro) {
    console.error(erro);

    return res.status(500).json({
      erro: "Erro interno no servidor."
    });
  }
}
