(()=>{const cfg=window.VENDAAI_CONFIG||{};if(window.supabase&&cfg.SUPABASE_URL&&cfg.SUPABASE_ANON_KEY){window.marketplaceDb=window.supabase.createClient(cfg.SUPABASE_URL,cfg.SUPABASE_ANON_KEY)}function timeout(p,ms=8000,label='Operação'){return Promise.race([p,new Promise((_,rej)=>setTimeout(()=>rej(new Error(label+' demorou demais para responder.')),ms))])}window.MP={
esc(v){const d=document.createElement('div');d.textContent=v??'';return d.innerHTML},
money(v){return Number(v||0).toLocaleString('pt-BR',{style:'currency',currency:'BRL'})},
async session(){if(!window.marketplaceDb)throw new Error('Não foi possível conectar ao Supabase.');const{data,error}=await timeout(window.marketplaceDb.auth.getSession(),8000,'Sessão');if(error)throw error;return data?.session||null},
async requireUser(next=location.pathname.split('/').pop()||'vendedor-painel.html'){const s=await this.session();if(!s){location.href='login.html?next='+encodeURIComponent(next);return null}return s.user},
async storeFor(userId){const{data,error}=await timeout(window.marketplaceDb.from('marketplace_stores').select('*').eq('owner_id',userId).order('created_at',{ascending:true}).limit(1).maybeSingle(),8000,'Busca da loja');if(error)throw error;return data||null},
async profileFor(userId){const{data,error}=await timeout(window.marketplaceDb.from('marketplace_profiles').select('*').eq('user_id',userId).maybeSingle(),8000,'Busca do perfil');if(error)throw error;return data||null},
async isAdmin(){const s=await this.session();if(!s)return false;const{data,error}=await timeout(window.marketplaceDb.rpc('vendaai_is_marketplace_admin'),8000,'Verificação administrativa');if(error)throw error;return data===true},
categoryLabel(v){return({products:'Produtos',services:'Serviços',vehicles:'Veículos',real_estate:'Imóveis'})[v]||v},
categoryEmoji(v){return({products:'🛍️',services:'🔧',vehicles:'Veículos',real_estate:'🏠'})[v]||'🛒'}
}}})();