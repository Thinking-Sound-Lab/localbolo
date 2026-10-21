-- Real Postgres assertions; fixtures roll back. Never run against production.
begin;
create function pg_temp.check_ok(ok boolean, message text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception '%', message; end if; end $$;

do $$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid(); c uuid := gen_random_uuid();
  x uuid := gen_random_uuid(); y uuid := gen_random_uuid(); z uuid := gen_random_uuid();
  owner_id uuid; second_id uuid; first_key text; alias_key text;
  profile jsonb; result jsonb; first_instance uuid; second_instance uuid; third_instance uuid;
begin
  perform appsumo_apply_event(jsonb_build_object('event','purchase','license_key',a));
  perform pg_temp.check_ok(appsumo_claim(a) is null, 'purchase must not grant access');
  perform appsumo_apply_event(jsonb_build_object('event','activate','license_key',a,'tier',1,'license_status','inactive'));
  profile := appsumo_claim(a); owner_id := (profile->>'id')::uuid; first_key := profile->>'product_key';
  perform pg_temp.check_ok(profile->>'status' = 'active' and (profile->>'macs')::int = 1, 'activation ignores pre-ack status');
  result := appsumo_license_action(first_key,'activate',null,repeat('a',64),'First Mac');
  first_instance := (result->>'id')::uuid;
  perform pg_temp.check_ok(result->>'status' = '201', 'first Mac activates');
  result := appsumo_license_action(first_key,'activate',null,repeat('a',64),'Renamed Mac');
  perform pg_temp.check_ok((result->>'id')::uuid = first_instance, 'same Mac activation is idempotent');
  perform pg_temp.check_ok(appsumo_license_action(first_key,'activate',null,repeat('b',64),'Second Mac')->>'status' = '422', '1 Mac cap');

  -- The old key can deactivate before the upgrade, and late retries follow it.
  perform appsumo_apply_event(jsonb_build_object('event','deactivate','license_key',a));
  perform appsumo_apply_event(jsonb_build_object('event','upgrade','license_key',b,'prev_license_key',a,'tier',2));
  perform appsumo_apply_event(jsonb_build_object('event','deactivate','license_key',a,'event_timestamp',2));
  perform appsumo_apply_event(jsonb_build_object('event','purchase','license_key',a));
  profile := appsumo_claim(b);
  perform pg_temp.check_ok(profile->>'product_key' = first_key and profile->>'status' = 'active' and (profile->>'macs')::int = 2, 'upgrade preserves key and ignores old-key revocation');
  perform pg_temp.check_ok((appsumo_license_action(first_key,'validate',first_instance)->>'valid')::boolean, 'upgrade preserves original activation');
  result := appsumo_license_action(first_key,'activate',null,repeat('b',64),'Second Mac');
  second_instance := (result->>'id')::uuid;
  perform pg_temp.check_ok(result->>'status' = '201', 'second slot after upgrade');
  perform pg_temp.check_ok(appsumo_license_action(first_key,'activate',null,repeat('c',64),'Third Mac')->>'status' = '422', '2 Mac cap');

  perform appsumo_apply_event(jsonb_build_object('event','upgrade','license_key',c,'prev_license_key',b,'tier',3));
  for i in 3..5 loop
    result := appsumo_license_action(first_key,'activate',null,repeat(i::text,64),'Mac '||i);
    perform pg_temp.check_ok(result->>'status' = '201', '5 Mac slot');
  end loop;
  perform pg_temp.check_ok(appsumo_license_action(first_key,'activate',null,repeat('6',64),'Sixth Mac')->>'status' = '422', '5 Mac cap');
  perform appsumo_apply_event(jsonb_build_object('event','upgrade','license_key',c,'prev_license_key',b,'tier',3,'event_timestamp',99));
  perform pg_temp.check_ok((select count(*) = 1 from appsumo_licenses where id = owner_id and merged_into is null), 'retry cannot duplicate license');

  perform appsumo_apply_event(jsonb_build_object('event','downgrade','license_key',x,'prev_license_key',c,'tier',1));
  perform pg_temp.check_ok((appsumo_profile(owner_id)->>'macs')::int = 1 and jsonb_array_length(appsumo_profile(owner_id)->'devices') = 1, 'downgrade clamps active Macs');
  perform pg_temp.check_ok((appsumo_license_action(first_key,'validate',first_instance)->>'valid')::boolean, 'oldest Mac stays active');
  perform pg_temp.check_ok(not (appsumo_license_action(first_key,'validate',second_instance)->>'valid')::boolean, 'excess Mac revoked');

  perform appsumo_release_device(owner_id, first_instance);
  result := appsumo_license_action(first_key,'activate',null,repeat('b',64),'Replacement Mac');
  third_instance := (result->>'id')::uuid;
  perform pg_temp.check_ok(result->>'status' = '201' and third_instance <> second_instance, 'removed Mac receives fresh instance');
  perform pg_temp.check_ok(not (appsumo_license_action(first_key,'validate',second_instance)->>'valid')::boolean, 'removed instance stays revoked');

  perform appsumo_apply_event(jsonb_build_object('event','activate','license_key',y,'tier',1));
  profile := appsumo_claim(y); second_id := (profile->>'id')::uuid; alias_key := profile->>'product_key';
  perform appsumo_release_device(second_id, third_instance);
  perform appsumo_license_action(alias_key,'deactivate',third_instance);
  perform pg_temp.check_ok((appsumo_license_action(first_key,'validate',third_instance)->>'valid')::boolean, 'other buyer cannot remove a Mac');
  perform pg_temp.check_ok(not (appsumo_license_action(alias_key,'validate',third_instance)->>'valid')::boolean, 'instance must belong to this key');

  perform appsumo_apply_event(jsonb_build_object('event','deactivate','license_key',x));
  perform appsumo_apply_event(jsonb_build_object('event','activate','license_key',x,'tier',1));
  perform appsumo_apply_event(jsonb_build_object('event','purchase','license_key',x,'tier',1));
  perform pg_temp.check_ok(appsumo_claim(x) is null and appsumo_profile(owner_id)->>'product_key' is null, 'old activation and purchase cannot undo refund');
  perform pg_temp.check_ok(appsumo_license_action(first_key,'validate',third_instance)->>'status' = '403', 'refunded license denied');
  perform appsumo_apply_event(jsonb_build_object('event','activate','license_key',x,'tier',1,'event_timestamp',100), true);
  perform pg_temp.check_ok(appsumo_claim(x) is null, 'API pre-ACK state must not undo a fresh refund');
  update appsumo_keys set deactivated_at = clock_timestamp() - interval '6 minutes' where license_key = x;
  perform appsumo_apply_event(jsonb_build_object('event','activate','license_key',x,'tier',1,'event_timestamp',101), true);
  perform pg_temp.check_ok(appsumo_claim(x)->>'product_key' = first_key, 'verified reactivation preserves key');

  -- A->B->C can arrive as B->C first, after C was already used.
  a := gen_random_uuid(); b := gen_random_uuid(); c := gen_random_uuid();
  perform appsumo_apply_event(jsonb_build_object('event','activate','license_key',a,'tier',1));
  profile := appsumo_claim(a); owner_id := (profile->>'id')::uuid; first_key := profile->>'product_key';
  perform appsumo_apply_event(jsonb_build_object('event','upgrade','license_key',c,'prev_license_key',b,'tier',3));
  profile := appsumo_claim(c); second_id := (profile->>'id')::uuid; alias_key := profile->>'product_key';
  result := appsumo_license_action(alias_key,'activate',null,repeat('a',64),'History Mac');
  first_instance := (result->>'id')::uuid;
  perform appsumo_apply_event(jsonb_build_object('event','upgrade','license_key',b,'prev_license_key',a,'tier',2));
  profile := appsumo_claim(c);
  perform pg_temp.check_ok(profile->>'product_key' = first_key and (profile->>'macs')::int = 5, 'reverse rotations keep latest tier and original key');
  perform pg_temp.check_ok(appsumo_profile(second_id)->>'id' = owner_id::text, 'old buyer session follows merged history');
  perform pg_temp.check_ok((appsumo_license_action(first_key,'validate',first_instance)->>'valid')::boolean, 'aliases share activation history');
  for i in 2..5 loop
    perform appsumo_license_action(first_key,'activate',null,repeat(i::text,64),'Alias Mac '||i);
  end loop;
  perform pg_temp.check_ok(appsumo_license_action(alias_key,'activate',null,repeat('6',64),'Alias overflow')->>'status' = '422', 'aliases share one cap');
  perform appsumo_apply_event(jsonb_build_object('event','deactivate','license_key',b));
  perform pg_temp.check_ok(appsumo_claim(c)->>'status' = 'active', 'old key in reverse chain cannot revoke current key');
  perform appsumo_apply_event(jsonb_build_object('event','deactivate','license_key',c));
  perform pg_temp.check_ok(appsumo_license_action(alias_key,'validate',first_instance)->>'status' = '403', 'refund revokes aliases too');

  perform appsumo_apply_event(jsonb_build_object('event','activate','license_key',z,'tier',3,'test',true));
  perform pg_temp.check_ok(not exists(select 1 from appsumo_keys where license_key = z), 'test events never grant access');
  perform pg_temp.check_ok(appsumo_rate_limit('fixture',2) and appsumo_rate_limit('fixture',2) and not appsumo_rate_limit('fixture',2), 'rate limits are enforced');
end $$;

select pg_temp.check_ok(not has_table_privilege('anon', 'appsumo_licenses', 'select'), 'anon cannot read keys');
select pg_temp.check_ok(not has_table_privilege('authenticated', 'appsumo_activations', 'select'), 'signed-in browser cannot read devices');
select pg_temp.check_ok(not has_function_privilege('anon', 'appsumo_profile(uuid)', 'execute'), 'anon cannot call privileged RPC');
select pg_temp.check_ok(not has_function_privilege('authenticated', 'appsumo_apply_event(jsonb,boolean)', 'execute'), 'signed-in browser cannot mint licenses');
rollback;
