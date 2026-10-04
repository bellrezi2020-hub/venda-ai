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
      empresa,
      imoveis
    } = req.body;


    if (!mensagem || !mensagem.trim()) {

      return res.status(400).json({
        erro: "Mensagem não informada."
      });

    }


    const catalogo =
      Array.isArray(imoveis)
        ? imoveis
        : [];


    const catalogoTexto =
      catalogo.length
        ? catalogo.map((imovel, index) => `

IMÓVEL ${index + 1}

ID: ${imovel.id}
Título: ${imovel.titulo}
Tipo: ${imovel.tipo}
Finalidade: ${imovel.finalidade}
Preço: R$ ${imovel.preco}
Bairro: ${imovel.bairro || "Não informado"}
Cidade: ${imovel.cidade || "Não informado"}
Quartos: ${imovel.quartos || "Não informado"}
Garagem: ${imovel.garagem || "Não informado"}
Descrição: ${imovel.descricao || "Não informado"}

`).join("\n")

        : "Nenhum imóvel cadastrado.";


    const prompt = `

Você é um assistente comercial especialista
em vendas imobiliárias.

Você trabalha para:

EMPRESA

Nome:
${empresa?.nome || "Não informado"}

Região:
${empresa?.regiao || "Não informado"}

Diferenciais:
${empresa?.diferenciais || "Não informado"}

Observações:
${empresa?.observacoes || "Não informado"}


CLIENTE

Nome:
${nome || "Cliente"}

Mensagem:
${mensagem}


CATÁLOGO REAL DA IMOBILIÁRIA

${catalogoTexto}


TAREFA

Analise o cliente e determine:

1. Temperatura do lead:
Quente, Morno ou Frio.

QUENTE:
quer comprar/alugar logo,
tem necessidade concreta,
prazo, orçamento ou forte intenção.

MORNO:
tem interesse real,
mas ainda está comparando ou sem prazo.

FRIO:
está apenas pesquisando
ou sem intenção comercial clara.


2. Resuma a intenção do cliente.


3. Analise SOMENTE os imóveis
presentes no catálogo.

Escolha no máximo 3 imóveis compatíveis.

Um imóvel deve ser compatível considerando:

- compra ou aluguel
- tipo
- orçamento
- cidade
- bairro
- quartos
- garagem
- outras exigências mencionadas

Nunca invente imóveis.

Nunca diga que existe uma opção
que não esteja no catálogo.

Se nenhum imóvel for compatível,
retorne uma lista vazia.


4. Escreva uma resposta comercial
natural para enviar ao cliente.

Se houver imóvel compatível,
mencione que existem opções compatíveis,
mas não invente características.

Se não houver,
explique educadamente que
não encontrou uma opção exata
e faça uma pergunta útil.


5. Determine o próximo passo comercial.


REGRAS IMPORTANTES

Não invente preço.

Não invente disponibilidade.

Não invente localização.

Não invente características.

Não prometa desconto.

Não invente financiamento.

Use somente dados fornecidos.

Responda em português do Brasil.

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
