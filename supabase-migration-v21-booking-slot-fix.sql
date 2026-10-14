-- VendaAI V21 — corrige proteção do status do horário
-- Execute depois da V20.

create or replace function public.vendaai_guard_availability_slot()
returns trigger
language plpgsql
set search_path=public
as $$
declare
  v_admin boolean := public.vendaai_is_marketplace_admin();
begin
  -- Admin e alterações internas disparadas por outros triggers podem prosseguir.
  if v_admin or pg_trigger_depth()>1 then
    if TG_OP='DELETE' then return OLD; end if;
    return NEW;
  end if;

  if TG_OP='INSERT' then
    if NEW.seller_id is distinct from auth.uid() then
      raise exception 'Prestador inválido.';
    end if;
    NEW.status := 'available';
    return NEW;
  end if;

  if TG_OP='DELETE' then
    if OLD.seller_id is distinct from auth.uid() then
      raise exception 'Apenas o prestador pode remover este horário.';
    end if;
    if OLD.status<>'available' then
      raise exception 'Horário reservado não pode ser removido.';
    end if;
    return OLD;
  end if;

  -- Campos estruturais nunca podem mudar.
  if NEW.seller_id is distinct from OLD.seller_id
     or NEW.listing_id is distinct from OLD.listing_id then
    raise exception 'Campos protegidos do horário não podem ser alterados.';
  end if;

  -- Se quem chamou NÃO é o vendedor, a alteração só é permitida
  -- para transições internas seguras feitas pelas funções da plataforma.
  if auth.uid() is distinct from OLD.seller_id then
    if (OLD.status='available' and NEW.status='reserved')
       or (OLD.status='reserved' and NEW.status in ('available','blocked')) then
      return NEW;
    end if;

    raise exception 'Alteração de horário não permitida.';
  end if;

  -- Vendedor pode editar data/hora apenas enquanto o slot está disponível,
  -- mas não pode forçar manualmente reserved/blocked.
  if NEW.status is distinct from OLD.status then
    raise exception 'O status do horário é controlado pela VendaAI.';
  end if;

  if OLD.status<>'available'
     and (NEW.starts_at is distinct from OLD.starts_at
          or NEW.ends_at is distinct from OLD.ends_at) then
    raise exception 'Horário reservado não pode ser alterado.';
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_mp_guard_availability_slot on marketplace_availability_slots;
create trigger trg_mp_guard_availability_slot
before insert or update or delete on marketplace_availability_slots
for each row execute function public.vendaai_guard_availability_slot();
