-- LocalBolo isn't sold on AppSumo, so remove its licensing service. The only
-- row it ever held came from AppSumo's URL validation, never from a buyer.
drop function if exists public.appsumo_apply_event(jsonb, boolean);
drop function if exists public.appsumo_claim(uuid);
drop function if exists public.appsumo_ensure_key(uuid);
drop function if exists public.appsumo_license_action(text, text, uuid, text, text);
drop function if exists public.appsumo_needs_reactivation(uuid);
drop function if exists public.appsumo_profile(uuid);
drop function if exists public.appsumo_rate_limit(text, integer, integer);
drop function if exists public.appsumo_reactivation_ready(uuid);
drop function if exists public.appsumo_release_device(uuid, uuid);
drop function if exists public.appsumo_resolve_license(uuid);

drop table if exists
  public.appsumo_activations,
  public.appsumo_product_keys,
  public.appsumo_keys,
  public.appsumo_events,
  public.appsumo_rate_limits,
  public.appsumo_licenses;
