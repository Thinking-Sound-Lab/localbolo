-- Create or lock the bucket in one statement. Inserting with DO NOTHING left an
-- existing expired bucket unlocked, so another request's cleanup could delete it
-- before this request locked it, and the request passed without being counted.
create or replace function public.appsumo_rate_limit(p_bucket text, p_limit integer, p_seconds integer default 60)
returns boolean language plpgsql set search_path = public, pg_temp as $$
declare recent timestamptz[]; checked_at timestamptz;
begin
  if p_limit not between 1 and 1000 or p_seconds not between 1 and 3600 then
    raise exception 'Invalid rate limit';
  end if;
  insert into appsumo_rate_limits as r (bucket, expires_at) values (p_bucket, clock_timestamp())
    on conflict (bucket) do update set expires_at = r.expires_at
    returning r.hits into recent;
  -- Read the clock after acquiring the row lock so waiting requests share a
  -- true rolling window, rather than getting another quota at a fixed boundary.
  checked_at := clock_timestamp();
  select coalesce(array_agg(hit), '{}') into recent from unnest(recent) hit
    where hit > checked_at - make_interval(secs => p_seconds);
  if cardinality(recent) >= p_limit then return false; end if;
  update appsumo_rate_limits set hits = array_append(recent, checked_at),
    expires_at = checked_at + make_interval(secs => p_seconds) where bucket = p_bucket;
  -- Lock this bucket first, then clean others without waiting on their locks.
  delete from appsumo_rate_limits where bucket in (
    select bucket from appsumo_rate_limits where expires_at < checked_at and bucket <> p_bucket
    limit 100 for update skip locked
  );
  return true;
end $$;

revoke all on function public.appsumo_rate_limit(text, integer, integer) from public, anon, authenticated;
grant execute on function public.appsumo_rate_limit(text, integer, integer) to service_role;
