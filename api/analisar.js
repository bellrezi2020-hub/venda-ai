export default async function handler(req,res){
 if(req.method!=="POST") return res.status(405).json({erro:"Método não permitido"});
 try{
  const {nome,mensagem,empresa,imoveis}=req.body;
  if(!mensagem?.trim()) return res.status(400).json({erro:"Mensagem não informada."});
  const catalogo=(imoveis||[]).map((i,n)=>`IMÓVEL ${n+1}
Título: ${i.title||i.titulo}
Tipo: ${i.type||i.tipo}
Finalidade: ${i.purpose||i.finalidade}
Preço: R$ ${i.price||i.preco}
Bairro: ${i.neighborhood||i.bairro||"Não informado"}
Cidade: ${i.city||i.cidade||"Não informado"}
Quartos: ${i.bedrooms||i.quartos||"Não informado"}
Garagem: ${(i.garage??i.garagem)==true||i.garagem==="Sim"?"Sim":"Não"}
Descrição: ${i.description||i.descricao||""}`).join("\n\n")||"Nenhum imóvel cadastrado.";
  const prompt=`Você é um assistente comercial de uma imobiliária.
EMPRESA
Nome: ${empresa?.name||empresa?.nome||"Não informado"}
Região: ${empresa?.region||empresa?.regiao||"Não informado"}
Diferenciais: ${empresa?.differentials||empresa?.diferenciais||"Não informado"}
Observações: ${empresa?.notes||empresa?.observacoes||"Não informado"}

CLIENTE
Nome: ${nome||"Cliente"}
Mensagem: ${mensagem}

CATÁLOGO REAL
${catalogo}

Retorne:
- status: Quente, Morno ou Frio
- intencao
- resposta
- proximoPasso
- imoveisCompativeis: no máximo 3, cada um com titulo e motivo

Regras: use somente o catálogo real; não invente imóvel, preço, localização, disponibilidade, desconto ou financiamento.`;
  const r=await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent",{method:"POST",headers:{"Content-Type":"application/json","x-goog-api-key":process.env.GEMINI_API_KEY},body:JSON.stringify({contents:[{parts:[{text:prompt}]}],generationConfig:{responseMimeType:"application/json",responseSchema:{type:"OBJECT",properties:{status:{type:"STRING"},intencao:{type:"STRING"},resposta:{type:"STRING"},proximoPasso:{type:"STRING"},imoveisCompativeis:{type:"ARRAY",items:{type:"OBJECT",properties:{titulo:{type:"STRING"},motivo:{type:"STRING"}},required:["titulo","motivo"]}}},required:["status","intencao","resposta","proximoPasso","imoveisCompativeis"]}}})});
  const d=await r.json();if(!r.ok)return res.status(500).json({erro:"Erro ao consultar a IA.",detalhe:d});
  const txt=d?.candidates?.[0]?.content?.parts?.[0]?.text;if(!txt)return res.status(500).json({erro:"A IA não retornou análise."});
  res.status(200).json(JSON.parse(txt));
 }catch(e){console.error(e);res.status(500).json({erro:"Erro interno no servidor."})}
}
