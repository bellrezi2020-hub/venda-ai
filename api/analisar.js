import { requireCompanyAccess, apiError } from "./_auth.js";
import { checkAndConsumeAI } from "./_usage.js";

export default async function handler(req,res){
  if(req.method!=="POST") return res.status(405).json({erro:"Método não permitido"});

  try{
    const {nome,mensagem,empresa,imoveis}=req.body||{};

    if(!empresa?.id)
      return res.status(400).json({erro:"Empresa não informada."});

    const {admin}=await requireCompanyAccess(req,empresa.id,{ownerOnly:true});

    const msg=String(mensagem||"").trim();

    if(!msg)
      return res.status(400).json({erro:"Mensagem não informada."});

    if(msg.length>4000)
      return res.status(400).json({erro:"Mensagem muito longa. Limite: 4.000 caracteres."});

    await checkAndConsumeAI(admin,empresa.id,1);

    const catalogo=(imoveis||[])
      .slice(0,200)
      .map(i=>`${i.title}|${i.type}|${i.purpose}|R$${i.price}|${i.neighborhood||""}|${i.city||""}|${i.bedrooms||0} quartos|garagem ${i.garage?"sim":"não"}|${String(i.description||"").slice(0,300)}`)
      .join("\n") || "Sem imóveis.";

    const prompt=`Você é um assistente comercial imobiliário.
Empresa: ${empresa?.name||""}
Região: ${empresa?.region||""}
Diferenciais: ${empresa?.differentials||""}

Cliente: ${String(nome||"Cliente").slice(0,120)}
Mensagem: ${msg}

Catálogo real:
${catalogo}

Retorne JSON com status (somente Quente, Morno ou Frio), intencao, resposta, proximoPasso e imoveisCompativeis (máximo 3 com titulo e motivo).
Nunca invente imóvel, preço, disponibilidade, desconto, endereço, financiamento ou confirmação de visita.`;

    const r=await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent",
      {
        method:"POST",
        headers:{
          "Content-Type":"application/json",
          "x-goog-api-key":process.env.GEMINI_API_KEY
        },
        body:JSON.stringify({
          contents:[{parts:[{text:prompt}]}],
          generationConfig:{
            responseMimeType:"application/json",
            responseSchema:{
              type:"OBJECT",
              properties:{
                status:{type:"STRING",enum:["Quente","Morno","Frio"]},
                intencao:{type:"STRING"},
                resposta:{type:"STRING"},
                proximoPasso:{type:"STRING"},
                imoveisCompativeis:{
                  type:"ARRAY",
                  items:{
                    type:"OBJECT",
                    properties:{titulo:{type:"STRING"},motivo:{type:"STRING"}},
                    required:["titulo","motivo"]
                  }
                }
              },
              required:["status","intencao","resposta","proximoPasso","imoveisCompativeis"]
            }
          }
        })
      }
    );

    const d=await r.json();

    if(!r.ok)
      return res.status(500).json({erro:"Erro ao consultar IA."});

    return res.status(200).json(JSON.parse(d.candidates[0].content.parts[0].text));
  }catch(e){
    return apiError(res,e);
  }
}
