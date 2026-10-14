(()=>{
const cfg=window.VENDAAI_CONFIG||{};
const ref=String(cfg.SUPABASE_URL||'').match(/https:\/\/([^.]+)\./)?.[1]||'';
const authKey=ref?'sb-'+ref+'-auth-token':'';

function readStoredSession(){
  try{
    const raw=authKey?localStorage.getItem(authKey):null;
    if(!raw)return null;
    const parsed=JSON.parse(raw);
    return parsed?.currentSession||parsed;
  }catch(e){return null}
}

function timeout(p,ms=10000,label='Operação'){
  return Promise.race([
    p,
    new Promise((_,rej)=>setTimeout(()=>rej(new Error(label+' demorou demais para responder.')),ms))
  ]);
}

if(window.supabase&&cfg.SUPABASE_URL&&cfg.SUPABASE_ANON_KEY){
  window.marketplaceDb=window.supabase.createClient(
    cfg.SUPABASE_URL,
    cfg.SUPABASE_ANON_KEY,
    {auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}}
  );
}

window.MP={
  esc(v){const d=document.createElement('div');d.textContent=v??'';return d.innerHTML},
  money(v){return Number(v||0).toLocaleString('pt-BR',{style:'currency',currency:'BRL'})},

  async session(){
    if(!window.marketplaceDb)throw new Error('Não foi possível conectar ao Supabase.');

    let s=readStoredSession();
    if(!s?.refresh_token)return null;

    const now=Math.floor(Date.now()/1000);
    const exp=Number(s.expires_at||0);

    if(s.access_token && exp>now+60){
      await marketplaceDb.auth.setSession({
        access_token:s.access_token,
        refresh_token:s.refresh_token
      });
      return s;
    }

    const {data,error}=await timeout(
      marketplaceDb.auth.refreshSession({refresh_token:s.refresh_token}),
      10000,
      'Renovação do login'
    );

    if(error)throw error;
    if(!data?.session)return null;

    return data.session;
  },

  async requireUser(next=location.pathname.split('/').pop()||'vendedor-painel.html'){
    const s=await this.session();
    if(!s){
      location.href='login.html?next='+encodeURIComponent(next);
      return null;
    }
    return s.user;
  },

  async storeFor(userId){
    const{data,error}=await timeout(
      marketplaceDb.from('marketplace_stores').select('*').eq('owner_id',userId).order('created_at',{ascending:true}).limit(1).maybeSingle(),
      10000,'Busca da loja'
    );
    if(error)throw error;
    return data||null;
  },

  async profileFor(userId){
    const{data,error}=await timeout(
      marketplaceDb.from('marketplace_profiles').select('*').eq('user_id',userId).maybeSingle(),
      10000,'Busca do perfil'
    );
    if(error)throw error;
    return data||null;
  },

  async isAdmin(){
    const s=await this.session();
    if(!s)return false;
    const{data,error}=await timeout(
      marketplaceDb.rpc('vendaai_is_marketplace_admin'),
      10000,'Verificação administrativa'
    );
    if(error)throw error;
    return data===true;
  },

  async logout(){
    try{await marketplaceDb.auth.signOut()}catch(e){}
    location.href='index.html';
  },

  categoryLabel(v){return({products:'Produtos',services:'Serviços',vehicles:'Veículos',real_estate:'Imóveis'})[v]||v},
  categoryEmoji(v){return({products:'🛍️',services:'🔧',vehicles:'🚗',real_estate:'🏠'})[v]||'🛒'},

  async unreadCount(){
    const s=await this.session();
    if(!s)return 0;
    const{count,error}=await marketplaceDb.from('marketplace_notifications').select('id',{count:'exact',head:true}).eq('user_id',s.user.id).eq('is_read',false);
    if(error)return 0;
    return count||0;
  }
};

document.addEventListener('DOMContentLoaded',async()=>{
  try{
    const s=await MP.session();
    if(!s)return;
    const n=await MP.unreadCount();
    document.querySelectorAll('a[href*="notificacoes.html"]').forEach(a=>{
      const base='Notificações';
      a.textContent=n>0?base+' ('+n+')':base;
    });
    document.querySelectorAll('a[href^="login.html"]').forEach(a=>{
      a.href='perfil.html';
      a.textContent='Meu perfil';
    });
  }catch(e){}
});
})();