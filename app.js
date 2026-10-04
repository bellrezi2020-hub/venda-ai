const cfg = window.VENDAAI_CONFIG || {};
let supabaseClient = null;

if (window.supabase && cfg.SUPABASE_URL && !cfg.SUPABASE_URL.startsWith("COLE_")) {
  supabaseClient = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY);
}

function esc(t){
  const d=document.createElement("div");
  d.textContent=t ?? "";
  return d.innerHTML;
}
function normalizar(t){
  return String(t||"").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
}
function dinheiro(v){
  return Number(v||0).toLocaleString("pt-BR",{style:"currency",currency:"BRL"});
}
async function requireAuth(){
  if(!supabaseClient){
    alert("Configure o Supabase em config.js.");
    location.href="login.html";
    return null;
  }
  const {data:{session}}=await supabaseClient.auth.getSession();
  if(!session){ location.href="login.html"; return null; }
  return session.user;
}
async function logout(){
  if(supabaseClient) await supabaseClient.auth.signOut();
  location.href="login.html";
}
async function currentCompany(){
  const user=await requireAuth(); if(!user) return null;
  const {data,error}=await supabaseClient.from("companies").select("*").eq("owner_id",user.id).maybeSingle();
  if(error){console.error(error);return null}
  return data;
}
function nav(active){
  return `
  <header>
    <div class="logo">Venda<span>AI</span></div>
    <nav>
      <a href="index.html" class="${active==="dashboard"?"ativo":""}">Dashboard</a>
      <a href="empresa.html" class="${active==="empresa"?"ativo":""}">Empresa</a>
      <a href="imoveis.html" class="${active==="imoveis"?"ativo":""}">Imóveis</a>
      <a href="leads.html" class="${active==="leads"?"ativo":""}">Leads</a>
      <a href="followups.html" class="${active==="followups"?"ativo":""}">Follow-ups</a>
      <a href="planos.html" class="${active==="planos"?"ativo":""}">Planos</a>
      <a href="#" onclick="logout();return false">Sair</a>
    </nav>
  </header>`;
}
