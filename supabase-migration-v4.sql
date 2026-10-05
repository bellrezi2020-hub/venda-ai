-- VendaAI V4 - segurança dono x corretor. Não apaga dados.

create or replace function public.is_company_member(company uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.company_members cm
    where cm.company_id = company and cm.user_id = auth.uid()
  );
$$;

create or replace function public.is_company_owner(company uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.companies c
    where c.id = company and c.owner_id = auth.uid()
  );
$$;

grant execute on function public.is_company_member(uuid) to authenticated;
grant execute on function public.is_company_owner(uuid) to authenticated;

-- COMPANIES
drop policy if exists companies_owner_all on companies;
drop policy if exists companies_members_select on companies;
drop policy if exists companies_owner_insert on companies;
drop policy if exists companies_owner_update on companies;
drop policy if exists companies_owner_delete on companies;

create policy companies_members_select on companies for select
using (owner_id = auth.uid() or public.is_company_member(id));

create policy companies_owner_insert on companies for insert
with check (owner_id = auth.uid());

create policy companies_owner_update on companies for update
using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy companies_owner_delete on companies for delete
using (owner_id = auth.uid());

-- MEMBERS
drop policy if exists members_company_select on company_members;
drop policy if exists company_members_owner_all on company_members;
drop policy if exists company_members_self_select on company_members;

create policy company_members_self_select on company_members for select
using (user_id = auth.uid() or public.is_company_owner(company_id));

create policy company_members_owner_all on company_members for all
using (public.is_company_owner(company_id))
with check (public.is_company_owner(company_id));

-- PROFILES
drop policy if exists profiles_self_select on profiles;
drop policy if exists profiles_team_select on profiles;
drop policy if exists profiles_self_update on profiles;

create policy profiles_team_select on profiles for select
using (
  id = auth.uid()
  or exists (
    select 1 from public.company_members target
    where target.user_id = profiles.id
      and public.is_company_owner(target.company_id)
  )
);

create policy profiles_self_update on profiles for update
using (id = auth.uid()) with check (id = auth.uid());

-- PROPERTIES
drop policy if exists properties_owner_all on properties;
drop policy if exists properties_company_select on properties;
drop policy if exists properties_owner_insert on properties;
drop policy if exists properties_owner_update on properties;
drop policy if exists properties_owner_delete on properties;

create policy properties_company_select on properties for select
using (public.is_company_owner(company_id) or public.is_company_member(company_id));

create policy properties_owner_insert on properties for insert
with check (public.is_company_owner(company_id));

create policy properties_owner_update on properties for update
using (public.is_company_owner(company_id))
with check (public.is_company_owner(company_id));

create policy properties_owner_delete on properties for delete
using (public.is_company_owner(company_id));

-- LEADS
drop policy if exists leads_owner_all on leads;
drop policy if exists leads_access_select on leads;
drop policy if exists leads_owner_insert on leads;
drop policy if exists leads_access_update on leads;
drop policy if exists leads_owner_delete on leads;

create policy leads_access_select on leads for select
using (
  public.is_company_owner(company_id)
  or (public.is_company_member(company_id) and assigned_to = auth.uid())
);

create policy leads_owner_insert on leads for insert
with check (public.is_company_owner(company_id));

create policy leads_access_update on leads for update
using (
  public.is_company_owner(company_id)
  or (public.is_company_member(company_id) and assigned_to = auth.uid())
)
with check (
  public.is_company_owner(company_id)
  or (public.is_company_member(company_id) and assigned_to = auth.uid())
);

create policy leads_owner_delete on leads for delete
using (public.is_company_owner(company_id));

-- MESSAGES
drop policy if exists messages_owner_all on messages;
drop policy if exists messages_access_select on messages;
drop policy if exists messages_access_insert on messages;
drop policy if exists messages_owner_delete on messages;

create policy messages_access_select on messages for select
using (
  exists (
    select 1 from leads l
    where l.id = messages.lead_id
      and (
        public.is_company_owner(l.company_id)
        or (public.is_company_member(l.company_id) and l.assigned_to = auth.uid())
      )
  )
);

create policy messages_access_insert on messages for insert
with check (
  exists (
    select 1 from leads l
    where l.id = messages.lead_id
      and (
        public.is_company_owner(l.company_id)
        or (public.is_company_member(l.company_id) and l.assigned_to = auth.uid())
      )
  )
);

create policy messages_owner_delete on messages for delete
using (
  exists (
    select 1 from leads l
    where l.id = messages.lead_id
      and public.is_company_owner(l.company_id)
  )
);

create index if not exists leads_assigned_to_idx on leads(assigned_to);
create index if not exists company_members_user_idx on company_members(user_id);
create index if not exists company_members_company_idx on company_members(company_id);
