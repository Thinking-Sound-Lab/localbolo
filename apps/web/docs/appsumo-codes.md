# LocalBolo license plans and code exports

Every new purchase includes **one non-expiring license key**. The selected plan
sets how many Macs can activate that key at the same time.

| Plan | Original USD | Buyer pays USD | Keys | Mac limit per key |
| --- | ---: | ---: | ---: | ---: |
| 1 Mac | $69 | $49 | 1 | 1 |
| 2 Macs | $159 | $99 | 1 | 2 |
| 5 Macs | $399 | $299 | 1 | 5 |

The website selects a separate Dodo product for each plan, always with checkout
quantity **1**. It verifies the price and license entitlement, then checks a quote
before redirecting to checkout. Dodo calculates applicable taxes. Existing keys
keep their original activation limits; do not edit the entitlements attached to
old purchases.

## Configure the website catalog

From `apps/web`, with the matching Dodo API key and mode loaded:

```sh
pnpm dodo:plans
pnpm dodo:plans --execute
```

The first command previews the setup. The second creates or reuses tagged products
and separate 1-, 2-, and 5-Mac entitlements, then prints these environment variables:

```dotenv
DODO_PAYMENTS_PRODUCT_ID=pdt_single
DODO_PAYMENTS_TWO_MAC_PRODUCT_ID=pdt_duo
DODO_PAYMENTS_FIVE_MAC_PRODUCT_ID=pdt_team
```

Test-mode products and keys do not work with the released app's live license server.
Repeat setup with a live API key and `DODO_PAYMENTS_ENVIRONMENT=live_mode`, then set
the live product IDs in Vercel Production before releasing the website change.
The checkout refuses a stale product with the wrong price or Mac limit.

## AppSumo submission 232888

The draft uses **Licensing** with three named tiers, each delivering one key with
the selected Mac limit. AppSumo manages its own license keys for this model, so a
10,000-code CSV is **not required**. A single shared CSV pool cannot distinguish
which one-key buyer should receive a 1-, 2-, or 5-Mac limit.

Fulfillment remains a separate launch requirement: implement and connect the
AppSumo licensing webhook and OAuth redirect, map each AppSumo tier to a Dodo key
with the correct activation limit, and handle upgrades, downgrades, and revocation.
An AppSumo-generated key will not activate the current Mac app directly. The
listing must remain a draft until this connection passes AppSumo's licensing tests.

## Export a separate batch of 10,000 working Dodo keys

Use this exporter if you need a batch of keys with **the same Mac limit**, for
example for a separately arranged code promotion. It is not the fulfillment path
for the three-tier AppSumo Licensing draft above.

The exporter registers each key with Dodo using `POST /license_keys`, sets the
chosen activation limit with no expiration, verifies every returned record and
public validation samples, and only then writes a CSV with a `code` header. It
creates no payments or customer emails.

1. In **live mode** in Dodo, create a dedicated customer for the inventory using
   your business email. Copy its customer ID (`cus_...`).
2. Put the live API key, three live product IDs, and mode in a private environment
   file, such as `~/.config/localbolo/appsumo.env`. Keep credentials out of chat and Git.
3. From `apps/web`, preview the batch, then run the export:

```sh
node --env-file="$HOME/.config/localbolo/appsumo.env" scripts/appsumo-codes.mjs --count 10000 --macs 1 --customer-id cus_YOUR_INVENTORY
node --env-file="$HOME/.config/localbolo/appsumo.env" scripts/appsumo-codes.mjs --count 10000 --macs 1 --customer-id cus_YOUR_INVENTORY --execute
```

Environment file:

```dotenv
DODO_PAYMENTS_ENVIRONMENT=live_mode
DODO_PAYMENTS_API_KEY=YOUR_LIVE_KEY
DODO_PAYMENTS_PRODUCT_ID=YOUR_LIVE_ONE_MAC_PRODUCT
DODO_PAYMENTS_TWO_MAC_PRODUCT_ID=YOUR_LIVE_TWO_MAC_PRODUCT
DODO_PAYMENTS_FIVE_MAC_PRODUCT_ID=YOUR_LIVE_FIVE_MAC_PRODUCT
```

Use `--macs 2` or `--macs 5` for a batch with those limits. The script selects and
verifies the matching product. Use a different `--output /private/path/codes.csv`
for each batch.

The default output is `~/.config/localbolo/appsumo-232888/codes.csv`, with private
file permissions. A batch identity file and journal beside it allow the exact same
command to resume after a failure. The SDK retries rate limits; do not start a
second run. If a process was forcibly killed, verify it is stopped before removing
its `.lock` file. Never share the CSV publicly.

Imported licenses have no Dodo payment attached. A refund through another platform
does not trigger Dodo's payment refund revocation: disable the corresponding key
in Dodo. Retain the private journal's key-to-ID mapping for this purpose. Buyers
must recover these imported codes through the promotion's fulfillment system;
they do not receive Dodo's purchase email.

References: [Dodo key import API](https://docs.dodopayments.com/api-reference/licenses/create-license-key),
[Dodo license lifecycle and quantity](https://docs.dodopayments.com/features/license-keys),
[AppSumo listing brief](https://partners.appsumo.com/docs/listing-brief.md),
[AppSumo licensing guide](https://docs.licensing.appsumo.com/).
