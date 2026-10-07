const cfg = window.VENDAAI_CONFIG || {};
let supabaseClient = null;

if (
  window.supabase &&
  cfg.SUPABASE_URL &&
  !String(cfg.SUPABASE_URL).startsWith("COLE_")
) {
  supabaseClient = window.supabase.createClient(
    cfg.SUPABASE_URL,
    cfg.SUPABASE_ANON_KEY
  );
}

function esc(t) {
  const d = document.createElement("div");
  d.textContent = t ?? "";
  return d.innerHTML;
}

function normalizar(t) {
  return String(t || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function dinheiro(v) {
  return Number(v || 0).toLocaleString("pt-BR", {
    style: "currency",
    currency: "BRL"
  });
}

function dataBR(v) {
  return v ? new Date(v).toLocaleString("pt-BR") : "";
}

async function requireAuth() {
  if (!supabaseClient) {
    alert("Configure o Supabase em config.js.");
    location.href = "login.html";
    return null;
  }

  const { data: { session } } = await supabaseClient.auth.getSession();

  if (!session) {
    location.href = "login.html";
    return null;
  }

  return session.user;
}

async function getSession() {
  const { data: { session } } = await supabaseClient.auth.getSession();
  return session;
}

async function authHeaders(extra = {}) {
  const session = await getSession();

  return {
    "Content-Type": "application/json",
    ...(session?.access_token
      ? { Authorization: `Bearer ${session.access_token}` }
      : {}),
    ...extra
  };
}

async function currentCompany() {
  const user = await requireAuth();
  if (!user) return null;

  const member = await supabaseClient
    .from("company_members")
    .select("company_id")
    .eq("user_id", user.id)
    .limit(1)
    .maybeSingle();

  if (member.data?.company_id) {
    const empresaEquipe = await supabaseClient
      .from("companies")
      .select("*")
      .eq("id", member.data.company_id)
      .maybeSingle();

    if (empresaEquipe.data) return empresaEquipe.data;
  }

  const own = await supabaseClient
    .from("companies")
    .select("*")
    .eq("owner_id", user.id)
    .maybeSingle();

  return own.data || null;
}

async function accessContext() {
  const user = await requireAuth();
  if (!user) return null;

  const company = await currentCompany();

  if (!company) {
    return {
      user,
      company: null,
      isOwner: false,
      role: null
    };
  }

  const isOwner = company.owner_id === user.id;
  let role = isOwner ? "owner" : "corretor";

  if (!isOwner) {
    const r = await supabaseClient
      .from("company_members")
      .select("role")
      .eq("company_id", company.id)
      .eq("user_id", user.id)
      .maybeSingle();

    role = r.data?.role || "corretor";
  }

  return {
    user,
    company,
    isOwner,
    role
  };
}

async function logout() {
  if (supabaseClient) {
    await supabaseClient.auth.signOut();
  }

  location.href = "login.html";
}

function nav(active, isOwner = true) {
  const ownerOnly = isOwner
    ? `
<a href="empresa.html" class="${active === "empresa" ? "ativo" : ""}">Empresa</a>
<a href="imoveis.html" class="${active === "imoveis" ? "ativo" : ""}">Imóveis</a>
<a href="equipe.html" class="${active === "equipe" ? "ativo" : ""}">Equipe</a>
<a href="vendas.html" class="${active === "vendas" ? "ativo" : ""}">Vendas</a>
<a href="integracoes.html" class="${active === "integracoes" ? "ativo" : ""}">Integrações</a>
<a href="configuracoes.html" class="${active === "configuracoes" ? "ativo" : ""}">Configurações</a>
`
    : "";

  return `
<header>
<div class="logo">Venda<span>AI</span></div>
<nav>
<a href="index.html" class="${active === "dashboard" ? "ativo" : ""}">Dashboard</a>
<a href="leads.html" class="${active === "leads" ? "ativo" : ""}">Leads</a>
<a href="pendencias.html" class="${active === "pendencias" ? "ativo" : ""}">Pendências</a>
${ownerOnly}
<a href="#" onclick="logout();return false;">Sair</a>
</nav>
</header>
`;
}

async function renderNav(active) {
  const ctx = await accessContext();
  if (!ctx) return null;

  const area = document.getElementById("nav");

  if (area) {
    area.innerHTML = nav(active, ctx.isOwner);
  }

  return ctx;
}

function requireOwner(ctx) {
  if (!ctx?.isOwner) {
    alert("Esta área é exclusiva do administrador.");
    location.href = "index.html";
    return false;
  }

  return true;
}
