export default async function handler(req,res){
 if(req.method!=="POST")return res.status(405).json({erro:"Método não permitido"});
 try{
  const {lead,empresa}=req.body;
  const prompt=`Crie UMA mensagem curta de follow-up para WhatsApp em português do Brasil.
Empresa: ${empresa?.name||""}
Cliente: ${lead?.name||""}
Temperatura: ${lead?.temperature||""}
Intenção: ${lead?.intent||""}
Próximo passo: ${lead?.next_step||""}
Seja natural, sem pressão e sem inventar informações.`;
  const r=await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent",{method:"POST",headers:{"Content-Type":"application/json","x-goog-api-key":process.env.GEMINI_API_KEY},body:JSON.stringify({contents:[{parts:[{text:prompt}]}]})});
  const d=await r.json();if(!r.ok)return res.status(500).json({erro:"Erro ao gerar follow-up"});
  res.status(200).json({resposta:d?.candidates?.[0]?.content?.parts?.[0]?.text||""});
 }catch(e){res.status(500).json({erro:"Erro interno."})}
}
