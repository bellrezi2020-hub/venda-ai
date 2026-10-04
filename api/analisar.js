export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ erro: "Método não permitido" });
  }

  try {
    const { nome, mensagem, negocio } = req.body;

    if (!mensagem) {
      return res.status(400).json({ erro: "Mensagem não informada." });
    }

    const prompt = `
Você é um assistente comercial especialista em qualificação de leads.

Tipo de negócio: ${negocio}
Nome do cliente: ${nome || "Cliente"}
Mensagem do cliente: ${mensagem}

Analise o cliente e retorne uma resposta curta e prática em português do Brasil.

Retorne exatamente neste formato:

STATUS: [Frio, Morno ou Quente]
INTENÇÃO: [o que o cliente procura]
RESPOSTA: [mensagem que a empresa deve enviar ao cliente]
PRÓXIMO PASSO: [qual pergunta ou ação deve ser feita para aproximar a venda]

Não invente informações que o cliente não forneceu.
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
          ]
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
      dados?.candidates?.[0]?.content?.parts?.[0]?.text ||
      "Não foi possível gerar uma resposta.";

    return res.status(200).json({ resposta: texto });

  } catch (erro) {
    console.error(erro);

    return res.status(500).json({
      erro: "Erro interno no servidor."
    });
  }
}

