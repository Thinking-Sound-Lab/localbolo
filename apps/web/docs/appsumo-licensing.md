# AppSumo licensing for LocalBolo

Submission **232888** uses AppSumo Licensing v2. No code CSV or live Dodo API key
is needed for this fulfillment path. Direct website purchases still use Dodo.

| AppSumo tier | Buyer pays | Original price | Macs per key |
| --- | ---: | ---: | ---: |
| 1 | $49 | $69 | 1 |
| 2 | $99 | $159 | 2 |
| 3 | $299 | $399 | 5 |

AppSumo generates the purchase's UUID license ID. The website stores every ID
and its event history, and creates one private LocalBolo activation key beginning
`LB-AS-`. That key stays the same through plan changes. A buyer uses it on every
Mac included in the plan. It is an activation credential, not an AppSumo redemption
code. Existing Dodo keys and separately exported `LBAS-` codes keep using Dodo.

## Configure and release

1. Apply `supabase/migrations/20261021010000_appsumo_licensing.sql` to the website's
   Supabase project using the normal migration workflow. It adds private tables
   and server-only RPCs; browser keys cannot read or mutate licenses.
2. Set these server-only variables in the intended Vercel environment, using
   separate credentials/database for staging. Never use `NEXT_PUBLIC_` names:

   ```dotenv
   SUPABASE_URL=https://YOUR_PROJECT.supabase.co
   SUPABASE_SECRET_KEY=YOUR_SERVER_SECRET
   APPSUMO_PRIVATE_KEY=YOUR_PARTNER_PORTAL_API_KEY
   APPSUMO_SESSION_SECRET=YOUR_RANDOM_SECRET_OF_AT_LEAST_32_CHARACTERS
   APPSUMO_REDIRECT_URI=https://localbolo.app/appsumo/callback
   ```

   Generate the session secret with `openssl rand -hex 32`. Use the AppSumo
   Partner Portal API key as the webhook signing key and private API credential.
3. Deploy the website. Register these URLs in AppSumo's licensing configuration:

   - Webhook: `https://localbolo.app/api/webhooks/appsumo`
   - OAuth redirect: `https://localbolo.app/appsumo/callback`

   The redirect responds with 200 when probed without a code. Signed `test: true`
   webhooks respond with `{ "event": "<received event>", "success": true }` and
   create no licenses. An unsigned request is rejected. These tests establish
   connectivity; they do not prove that a buyer can claim and use a license.
4. After URL validation, AppSumo generates OAuth credentials. Set
   `APPSUMO_CLIENT_ID` and `APPSUMO_CLIENT_SECRET` on the server and redeploy.
   `APPSUMO_REDIRECT_URI` must exactly match the registered URL. HTTPS is required
   in production. Keep credentials out of chat, logs, source control, and the app.
5. Release a Mac build containing the AppSumo client, with normal user-facing
   release notes. Release configuration uses `$(WEBSITE_URL)/api`; development
   configuration requires an explicit isolated staging URL in `Local.xcconfig`.
   Earlier released apps only understand Dodo keys and cannot activate AppSumo
   keys. Keep the AppSumo listing a draft until a compatible download is available.
6. Use **AppSumo-generated** test purchases/events to verify every tier, OAuth
   login and repeat login, upgrade/downgrade, refunds, and Mac activation against
   that released build. Do not manufacture live provider events. Only then make
   the listing ready for review through the normal submission workflow.

Production URLs have not been registered or validated by merely merging this
code. A Vercel preview behind sign-in cannot be used for AppSumo's webhook probe.
Coordinate URL changes with AppSumo if the product is already live.

## Buyer flow

The buyer opens LocalBolo in AppSumo My Products and chooses **Activate**. The
callback stores the one-time OAuth code in an encrypted HttpOnly cookie for at
most five minutes, removes the code from the browser address, and asks the buyer
to confirm the purchase. The same-origin, nonce-protected POST exchanges the code
on the server, verifies ownership through AppSumo and checks the private license
API against committed webhook state. It never grants access from URL parameters.

The buyer page shows their LocalBolo key, download instructions, and active Macs.
An encrypted HttpOnly session lasts 30 minutes; the buyer can hide it sooner or
return through AppSumo to reopen it. No separate LocalBolo account or email is
required. OAuth tokens are discarded after the ownership check. AppSumo pages
are excluded from analytics and search, and production responses disallow caching.
The callback suppresses referrers; the clean buyer page uses `same-origin` so
native form POSTs retain their Origin header without sending referrers elsewhere.

## Lifecycle and activation rules

- Raw webhook bytes are verified with HMAC SHA256 over `timestamp + body`, with
  a five-minute freshness window. ACKs follow a committed transaction.
- `purchase` only creates a placeholder. `activate` grants the tier even though
  the webhook's pre-ACK `license_status` is still `inactive`.
- Tier changes link `prev_license_key` to the new AppSumo ID. Old-key deactivation
  cannot revoke the current tier. Duplicate deliveries and reversed rotation
  histories retain a single activation allowance. Any key exposed before a late
  history merge remains an alias sharing that allowance.
- A downgrade keeps the oldest active Macs up to the new limit. The buyer can
  remove a Mac on the web page to choose another. A current-key refund denies
  activation and validation for every alias.
- A late activation cannot undo a refund. Intentional reactivation of the same
  AppSumo ID requires verification against AppSumo's current private API and a
  five-minute settling period after deactivation; a temporary error asks AppSumo
  to retry while its pre-ACK status settles.
- Activation takes a per-license database lock, so simultaneous requests cannot
  exceed the cap. Repeating activation on the same anonymous device returns the
  same instance. Removing and reactivating it mints a fresh instance, leaving the
  removed instance invalid. Instances are scoped to their owning license.
- The app rechecks roughly every 14 days and allows up to 30 days offline. A
  removed/refunded Mac loses access after a successful check, or needs to connect
  when its offline allowance expires. The server does not instantly stop an
  already-offline copy.

This integration has no AppSumo add-ons; add-on/migrate events do not grant access.
The private API has a shared budget below AppSumo's 20 requests/minute limit.
Public activation and claim endpoints also use database-backed rate limits.

## Support lookup

Use the authenticated Supabase **Table Editor** to search `appsumo_keys.license_key`
by the license ID the buyer sees in AppSumo. Every historical ID remains searchable.
For the current tier, product key and devices, use the private SQL Editor:

```sql
select public.appsumo_profile(license_id)
from public.appsumo_keys
where license_key = 'REPLACE_WITH_BUYERS_APPSUMO_UUID'::uuid;
```

`appsumo_events` retains signed event payloads for that ID. Device removal is
available to buyers from their own page, or to trusted support from SQL:

```sql
select public.appsumo_release_device('LICENSE_ID'::uuid, 'INSTANCE_ID'::uuid);
```

Do not share activation keys or event payloads publicly. Never grant anonymous
or browser-authenticated roles table/RPC access. If events were missed, inspect
AppSumo's license webhook history and use its supported retry/support process;
do not generate replacement AppSumo license IDs yourself.

## Local verification

From `apps/web`:

```sh
pnpm lint && pnpm test && pnpm build
pnpm test:licensing-db
```

The database command needs Docker and starts/removes a disposable PostgreSQL 17
container. It checks actual RPC behavior, RLS privileges, all three activation
caps under concurrent requests, lifecycle ordering, aliases, replacement devices,
and refunds. It uses no application secrets and makes no AppSumo requests.
Unit tests cover HMAC, cookies, OAuth request shape, CSRF, malformed requests,
test webhook isolation, and provider errors. Run the repository's Mac test and
Release build commands too. Local OAuth fixtures are not a live AppSumo check.

Protocol references: [official AppSumo guide](https://docs.licensing.appsumo.com/),
[webhook security](https://docs.licensing.appsumo.com/webhook/webhook__security.html),
[OAuth flow](https://docs.licensing.appsumo.com/licensing/licensing__connect.html).
