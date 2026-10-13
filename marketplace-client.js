(()=>{const cfg=window.VENDAAI_CONFIG||{};if(window.supabase&&cfg.SUPABASE_URL&&cfg.SUPABASE_ANON_KEY){window.marketplaceDb=window.supabase.createClient(cfg.SUPABASE_URL,cfg.SUPABASE_ANON_KEY)}window.MP={
esc(v){const d=document.createElement('div');d.textContent=v??'';return d.innerHTML},
money(v){return Number(v||0).toLocaleString('pt-BR',{style:'currency',currency:'BRL'})},
async session(){if(!window.marketplaceDb)return null;const{data}=await marketplaceDb.auth.getSession();return data.session||null},
async requireUser(next=location.pathname.split('/').pop()||'vendedor-painel.html'){const s=await this.session();if(!s){location.href='login.html?next='+encodeURIComponent(next);return null}return s.user},
async storeFor(userId){const{data}=await marketplaceDb.from('marketplace_stores').select('*').eq('owner_id',userId).order('created_at',{ascending:true}).limit(1).maybeSingle();return data||null},
async profileFor(userId){const{data}=await marketplaceDb.from('marketplace_profiles').select('*').eq('user_id',userId).maybeSingle();return data||null},
async isAdmin(){const s=await this.session();if(!s)return false;const{data}=await marketplaceDb.rpc('vendaai_is_marketplace_admin');return data===true},
categoryLabel(v){return({products:'Produtos',services:'Serviços',vehicles:'Veículos',real_estate:'Imóveis'})[v]||v},
categoryEmoji(v){return({products:'🛍️',services:'🔧',vehicles:'🚗',real_estate:'🏠'})[v]||'🛒'}
}}})();