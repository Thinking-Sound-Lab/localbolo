-- AppSumo licenses are separate from direct Dodo purchases. Only server RPCs
-- may touch this data; no browser Supabase key can read licenses or devices.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
grant usage on schema extensions to service_role;

create table public.appsumo_licenses (
  id uuid primary key default gen_random_uuid(),
  current_key uuid not null,
  product_key text not null unique default ('LB-AS-' || upper(encode(extensions.gen_random_bytes(32), 'hex'))),
  tier integer not null default 1 check (tier between 1 and 3),
  status text not null default 'inactive' check (status in ('inactive', 'active', 'deactivated')),
  merged_into uuid references public.appsumo_licenses(id),
  created_at timestamptz not null default now()
);
create table public.appsumo_keys (
  license_key uuid primary key,
  license_id uuid not null references public.appsumo_licenses(id),
  tier integer not null default 1 check (tier between 1 and 3),
  status text not null default 'inactive' check (status in ('inactive', 'active', 'deactivated')),
  replaced_by uuid,
  deactivated_at timestamptz
);
-- Preserve product keys and sessions if a delayed rotation joins two histories.
create table public.appsumo_product_keys (
  product_key text primary key,
  license_id uuid not null references public.appsumo_licenses(id)
);
create table public.appsumo_activations (
  id uuid primary key default gen_random_uuid(),
  license_id uuid not null references public.appsumo_licenses(id),
  device_id text not null,
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default clock_timestamp(),
  unique (license_id, device_id)
);
create table public.appsumo_events (
  payload_hash text primary key,
  license_key uuid not null,
  event text not null,
  payload jsonb not null,
  received_at timestamptz not null default now()
);
create table public.appsumo_rate_limits (
  bucket text primary key,
  requests integer not null,
  expires_at timestamptz not null
);
create index appsumo_keys_license_idx on public.appsumo_keys(license_id);
create index appsumo_activations_license_idx on public.appsumo_activations(license_id);
create index appsumo_events_key_idx on public.appsumo_events(license_key, received_at);
create index appsumo_rate_expiry_idx on public.appsumo_rate_limits(expires_at);

create function public.appsumo_resolve_license(p_id uuid) returns uuid
language plpgsql stable set search_path = public, pg_temp as $$
declare target uuid; cursor_id uuid := p_id;
begin
  for depth in 1..32 loop
    select merged_into into target from appsumo_licenses where id = cursor_id;
    if target is null then return cursor_id; end if;
    cursor_id := target;
  end loop;
  raise exception 'Invalid license history';
end $$;

create function public.appsumo_ensure_key(p_key uuid) returns uuid
language plpgsql set search_path = public, pg_temp as $$
declare result uuid; product text;
begin
  select license_id into result from appsumo_keys where license_key = p_key;
  if result is not null then return appsumo_resolve_license(result); end if;
  insert into appsumo_licenses(current_key) values (p_key) returning id, product_key into result, product;
  insert into appsumo_keys(license_key, license_id) values (p_key, result);
  insert into appsumo_product_keys values (product, result);
  return result;
end $$;

create function public.appsumo_apply_event(p_event jsonb, p_allow_reactivation boolean default false)
returns void language plpgsql set search_path = public, pg_temp as $$
declare
  key uuid := (p_event->>'license_key')::uuid;
  previous uuid := (p_event->>'prev_license_key')::uuid;
  kind text := p_event->>'event';
  plan integer := (p_event->>'tier')::integer;
  owner_id uuid; other_id uuid; other_current uuid; current uuid; existing_next uuid;
begin
  -- Serializes history merges, including rotations delivered in reverse order.
  -- Device requests also acquire this lock before their per-license row lock.
  perform pg_advisory_xact_lock(232888);
  if coalesce((p_event->>'test')::boolean, false) then return; end if;
  if kind not in ('purchase', 'activate', 'deactivate', 'upgrade', 'downgrade')
     or (kind in ('activate', 'upgrade', 'downgrade') and (plan is null or plan not between 1 and 3))
     or (plan is not null and plan not between 1 and 3) then
    raise exception 'Invalid AppSumo event';
  end if;
  insert into appsumo_events(payload_hash, license_key, event, payload)
    values (encode(extensions.digest(p_event::text, 'sha256'), 'hex'), key, kind, p_event)
    on conflict do nothing;
  if not found then return; end if;
  owner_id := appsumo_ensure_key(key);

  if kind in ('upgrade', 'downgrade') then
    if previous is null or previous = key then raise exception 'Missing previous license'; end if;
    other_id := owner_id;
    owner_id := appsumo_ensure_key(previous);
    select replaced_by into existing_next from appsumo_keys where license_key = previous;
    if existing_next is not null and existing_next <> key then raise exception 'Conflicting license history'; end if;

    if other_id <> owner_id then
      select current_key into other_current from appsumo_licenses where id = other_id;
      -- Keep the original buyer's product key. Any already-exposed placeholder
      -- key remains an alias to the same license and shares its activation cap.
      delete from appsumo_activations a where a.license_id = other_id and exists (
        select 1 from appsumo_activations b where b.license_id = owner_id and b.device_id = a.device_id
      );
      update appsumo_activations set license_id = owner_id where license_id = other_id;
      update appsumo_product_keys set license_id = owner_id where license_id = other_id;
      update appsumo_keys set license_id = owner_id where license_id = other_id;
      update appsumo_licenses set merged_into = owner_id, status = 'deactivated' where id = other_id;
      update appsumo_licenses set current_key = other_current where id = owner_id;
    else
      update appsumo_licenses set current_key = key where id = owner_id and current_key = previous;
    end if;
    update appsumo_keys set replaced_by = key, status = 'deactivated', deactivated_at = clock_timestamp() where license_key = previous;
    -- A refund can arrive before the upgrade retry. Never resurrect that key.
    update appsumo_keys set tier = plan,
      status = case when status = 'deactivated' then status else 'active' end
      where license_key = key;
  elsif kind = 'activate' then
    update appsumo_keys set tier = plan, status = 'active', deactivated_at = null where license_key = key
      and replaced_by is null and (status <> 'deactivated' or
        (p_allow_reactivation and deactivated_at <= clock_timestamp() - interval '5 minutes'));
  elsif kind = 'deactivate' then
    update appsumo_keys set status = 'deactivated', deactivated_at = clock_timestamp() where license_key = key;
  else
    -- A late purchase notification cannot undo activation, a refund, or a tier change.
    update appsumo_keys set tier = coalesce(plan, tier) where license_key = key and status = 'inactive';
  end if;

  select current_key into current from appsumo_licenses where id = owner_id;
  update appsumo_licenses l set tier = k.tier, status = k.status
    from appsumo_keys k where l.id = owner_id and k.license_key = current;
  -- A downgrade keeps the oldest active Macs. All remaining slots can be
  -- managed from the buyer page; revoked instances fail their next validation.
  update appsumo_activations set active = false where id in (
    select a.id from appsumo_activations a join appsumo_licenses l on l.id = a.license_id
    where a.license_id = owner_id and a.active
    order by a.created_at, a.id offset (select case tier when 1 then 1 when 2 then 2 else 5 end from appsumo_licenses where id = owner_id)
  );
end $$;

create function public.appsumo_profile(p_id uuid) returns jsonb
language plpgsql stable set search_path = public, pg_temp as $$
declare l appsumo_licenses;
begin
  select * into l from appsumo_licenses where id = appsumo_resolve_license(p_id);
  if not found then return null; end if;
  return jsonb_build_object('id', l.id, 'status', l.status, 'tier', l.tier,
    'macs', case l.tier when 1 then 1 when 2 then 2 else 5 end,
    'product_key', case when l.status = 'active' then l.product_key else null end,
    'devices', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'created_at', created_at) order by created_at, id)
      from appsumo_activations where license_id = l.id and active), '[]'::jsonb));
end $$;

create function public.appsumo_claim(p_key uuid) returns jsonb
language plpgsql stable set search_path = public, pg_temp as $$
declare owner_id uuid;
begin
  select l.id into owner_id from appsumo_keys k join appsumo_licenses l on l.id = k.license_id
    where k.license_key = p_key and l.current_key = p_key and l.status = 'active';
  if owner_id is null then return null; end if;
  return appsumo_profile(owner_id);
end $$;

create function public.appsumo_needs_reactivation(p_key uuid) returns boolean
language sql stable set search_path = public, pg_temp as $$
  select exists (select 1 from appsumo_keys
    where license_key = p_key and status = 'deactivated' and replaced_by is null);
$$;

-- AppSumo's API can still say "active" until it receives our refund ACK.
-- Allow that transition to settle before accepting a verified reactivation.
create function public.appsumo_reactivation_ready(p_key uuid) returns boolean
language sql stable set search_path = public, pg_temp as $$
  select exists (select 1 from appsumo_keys where license_key = p_key
    and status = 'deactivated' and replaced_by is null
    and deactivated_at <= now() - interval '5 minutes');
$$;

create function public.appsumo_license_action(p_key text, p_action text,
  p_instance uuid default null, p_device text default null, p_name text default null)
returns jsonb language plpgsql set search_path = public, pg_temp as $$
declare l appsumo_licenses; instance_id uuid; cap integer;
begin
  perform pg_advisory_xact_lock_shared(232888);
  select license_id into instance_id from appsumo_product_keys where product_key = p_key;
  if instance_id is null then return jsonb_build_object('status', 404); end if;
  select * into l from appsumo_licenses where id = appsumo_resolve_license(instance_id) for update;
  if l.status <> 'active' then return jsonb_build_object('status', 403); end if;
  if p_action = 'activate' then
    if p_device is null or p_device !~ '^[a-f0-9]{64}$' or p_name is null or length(p_name) not between 1 and 120 then
      return jsonb_build_object('status', 400);
    end if;
    select id into instance_id from appsumo_activations where license_id = l.id and device_id = p_device and active;
    if instance_id is not null then return jsonb_build_object('status', 201, 'id', instance_id); end if;
    cap := case l.tier when 1 then 1 when 2 then 2 else 5 end;
    if (select count(*) from appsumo_activations where license_id = l.id and active) >= cap then
      return jsonb_build_object('status', 422);
    end if;
    -- Mint a fresh activation ID when a previously removed Mac returns.
    delete from appsumo_activations where license_id = l.id and device_id = p_device;
    insert into appsumo_activations(license_id, device_id, name) values (l.id, p_device, p_name) returning id into instance_id;
    return jsonb_build_object('status', 201, 'id', instance_id);
  elsif p_action = 'validate' then
    return jsonb_build_object('status', 200, 'valid', exists (
      select 1 from appsumo_activations where license_id = l.id and id = p_instance and active
    ));
  elsif p_action = 'deactivate' then
    update appsumo_activations set active = false where license_id = l.id and id = p_instance;
    return jsonb_build_object('status', 200, 'success', true);
  end if;
  return jsonb_build_object('status', 400);
end $$;

create function public.appsumo_release_device(p_id uuid, p_instance uuid) returns void
language plpgsql set search_path = public, pg_temp as $$
declare owner_id uuid;
begin
  perform pg_advisory_xact_lock_shared(232888);
  owner_id := appsumo_resolve_license(p_id);
  perform 1 from appsumo_licenses where id = owner_id for update;
  update appsumo_activations set active = false where license_id = owner_id and id = p_instance;
end $$;

create function public.appsumo_rate_limit(p_bucket text, p_limit integer, p_seconds integer default 60)
returns boolean language plpgsql set search_path = public, pg_temp as $$
declare hits integer;
begin
  delete from appsumo_rate_limits where expires_at < now();
  insert into appsumo_rate_limits(bucket, requests, expires_at)
    values (p_bucket, 1, now() + make_interval(secs => p_seconds))
    on conflict (bucket) do update set requests = appsumo_rate_limits.requests + 1
    returning requests into hits;
  return hits <= p_limit;
end $$;

do $$ declare item record; begin
  for item in select tablename from pg_tables where schemaname = 'public' and tablename like 'appsumo_%' loop
    execute format('alter table public.%I enable row level security', item.tablename);
    execute format('revoke all on public.%I from public, anon, authenticated', item.tablename);
    execute format('grant select, insert, update, delete on public.%I to service_role', item.tablename);
  end loop;
  for item in select oid::regprocedure as fn from pg_proc where pronamespace = 'public'::regnamespace and proname like 'appsumo_%' loop
    execute format('revoke all on function %s from public, anon, authenticated', item.fn);
    execute format('grant execute on function %s to service_role', item.fn);
  end loop;
end $$;
