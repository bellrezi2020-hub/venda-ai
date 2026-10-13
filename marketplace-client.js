(()=>{
const cfg=window.VENDAAI_CONFIG||{};
const ref=String(cfg.SUPABASE_URL||'').match(/https:\/\/([^.]+)\./)?.[1]||'';
const authKey=ref?'sb-'+ref+'-auth-token':'';
function storedSession(){
  try{
    const raw=authKey?localStorage.getItem(authKey):null;
    if(!raw)return null;
    const parsed=JSON.parse(raw);
    return parsed?.currentSession||parsed;
  }catch(e){return null}
}
const cached=storedSession();
if(window.supabase&&cfg.SUPABASE_URL&&cfg.SUPABASE_ANON_KEY){
  const options={auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}};
  if(cached?.access_token){
    options.global={headers:{Authorization:'Bearer '+cached.access_token}};
  }
  window.marketplaceDb=window.supabase.createClient(cfg.SUPABASE_URL,cfg.SUPABASE_ANON_KEY,options);
}
function timeout(p,ms=8000,label='Operação'){return Promise.race([p,new Promise((_,rej)=>setTimeout(()=>rej(new Error(label+' demorou demais para responder.')),ms))])}
window.MP={
esc(v){const d=document.createElement('div');d.textContent=v??'';return d.innerHTML},
money(v){return Number(v||0).toLocaleString('pt-BR',{style:'currency',currency:'BRL'})},
session(){const s=storedSession();if(!s?.access_token||!s?.user)return null;return s},
async requireUser(next=location.pathname.split('/').pop()||'vendedor-painel.html'){const s=this.session();if(!s){location.href='login.html?next='+encodeURIComponent(next);return null}return s.user},
async storeFor(userId){if(!window.marketplaceDb)throw new Error('Não foi possível conectar ao Supabase.');const{data,error}=await timeout(window.marketplaceDb.from('marketplace_stores').select('*').eq('owner_id',userId).order('created_at',{ascending:true}).limit(1).maybeSingle(),8000,'Busca da loja');if(error)throw error;return data||null},
async profileFor(userId){if(!window.marketplaceDb)throw new Error('Não foi possível conectar ao Supabase.');const{data,error}=await timeout(window.marketplaceDb.from('marketplace_profiles').select('*').eq('user_id',userId).maybeSingle(),8000,'Busca do perfil');if(error)throw error;return data||null},
async isAdmin(){const s=this.session();if(!s)return false;const{data,error}=await timeout(window.marketplaceDb.rpc('vendaai_is_marketplace_admin'),8000,'Verificação administrativa');if(error)throw error;return data===true},
logout(){try{if(authKey)localStorage.removeItem(authKey)}catch(e){} location.href='index.html'},
categoryLabel(v){return({products:'Produtos',services:'Serviços',vehicles:'Veículos',real_estate:'Imóveis'})[v]||v},
categoryEmoji(v){return({products:'🛍️',services:'🔧',vehicles:'🚗',real_estate:'🏠'})[v]||'🛒'}
};
})();