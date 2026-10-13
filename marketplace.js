window.VendaAIMarketplace={
 money(v){return Number(v||0).toLocaleString('pt-BR',{style:'currency',currency:'BRL'})},
 sampleListings:[
  {id:'casa-1',cat:'Imóveis',title:'Casa 3 quartos com garagem',price:420000,city:'Sarandi - RS',emoji:'🏠',store:'Imobiliária Prime',rating:'4,9',verified:true},
  {id:'carro-1',cat:'Veículos',title:'SUV automático 2022',price:87900,city:'Passo Fundo - RS',emoji:'🚙',store:'AutoSul',rating:'4,8',verified:true},
  {id:'moda-1',cat:'Produtos',title:'Conjunto feminino premium',price:189.9,city:'Carazinho - RS',emoji:'👗',store:'Bella Moda',rating:'4,9',verified:true},
  {id:'unha-1',cat:'Serviços',title:'Alongamento em gel',price:120,city:'Sarandi - RS',emoji:'💅',store:'Studio Ana',rating:'5,0',verified:true}
 ],
 renderCards(target,items){const el=document.querySelector(target);if(!el)return;el.innerHTML=items.map(x=>`<article class="card product-card"><div class="product-img">${x.emoji}</div><div class="product-body"><div class="tag ok">${x.verified?'✓ Identidade verificada':'Novo vendedor'}</div><h3>${x.title}</h3><div class="price">${this.money(x.price)}</div><p class="muted">${x.city}</p><div class="store"><div class="avatar">${x.store.slice(0,1)}</div><div><strong>${x.store}</strong><div class="muted">⭐ ${x.rating}</div></div></div><a class="btn ghost" style="margin-top:14px;width:100%" href="anuncio.html?id=${encodeURIComponent(x.id)}">Ver anúncio</a></div></article>`).join('')},
 search(){const q=(document.querySelector('#q')?.value||'').trim();location.href='marketplace.html'+(q?'?q='+encodeURIComponent(q):'')},
 blockExternalContact(text){const rules=[/\b(?:\+?55\s?)?(?:\(?\d{2}\)?\s?)?9?\d{4}[-\s]?\d{4}\b/g,/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi,/https?:\/\/\S+/gi,/\b(?:instagram|whatsapp|telegram|pix)\b/gi,/@[a-z0-9._]{2,}/gi];let out=text;let hit=false;for(const r of rules){out=out.replace(r,()=>{hit=true;return '[contato ocultado]'});}return {text:out,hit}}
};