# LocalBolo website

The marketing site for LocalBolo, built with Next.js (App Router) and Tailwind CSS.

```sh
pnpm install
pnpm dev     # http://localhost:3000
pnpm build   # production build
pnpm lint
pnpm test    # unit tests (*.test.ts), with Node's built-in test runner
```

## Structure

```
src/
  app/                   Routes: home, support, changelog, privacy, terms, refunds,
                         plus icons and the files search engines read
    buy/route.ts         Starts a Dodo Payments checkout
    purchase/page.tsx    Where buyers land after checkout
    api/webhooks/dodo/   Verified Dodo Payments webhooks, which record purchases
  components/
    sections/            One file per home page section
    doc-page.tsx         Layout for long pages: numbered sections and "On this page"
    hero-demo.tsx        Animated dictation demo (client component)
    ascii-hover.tsx      Hero headline letters that turn into ASCII near the pointer
    pixel-wave.tsx       The hero's pixel voice waveform (canvas, client component)
    pixel-art.tsx        Draws pixel art from rows of text
    pixel-edge.tsx       Pixel "terrain" where a light section meets a dark one
    pixel-cascade.tsx    Pixels piling up from the corners of the final call to action
    card.tsx             Hairline cards, their 001-style numbers, and framed illustrations
    buy-button.tsx       The square Buy button, secondary links and corner marks
    logo.tsx             The wordmark (the logo) and the monogram
    pill.tsx             The dictation pill, matching the Mac app's design
  lib/
    site.ts              Name, price, refund window, contact, purchase link, footer links
    dodo.ts              The Dodo Payments client and product
    purchases.ts         The record of who bought LocalBolo, in Supabase
    models.ts            Speech model list (mirrors the Mac app)
    faq.ts               FAQ, shown on the page and published as structured data
    wordmark.ts          The wordmark as one SVG path, traced from the logo artwork
    monogram.ts          The monogram as one SVG path
    pixel-icons.ts       Every pixel-art icon, drawn as text, including a pixel wordmark
    metadata.ts          Per-page title, canonical URL and link previews
    structured-data.ts   schema.org data for the home page
supabase/migrations/     The database tables, in the order they were made
```

## Design

The layout follows dictation apps like Wispr Flow and Superwhisper: a centered hero with the
product demo, the apps it works in, then speed, how it works, features, privacy, models,
pricing, FAQ and a full footer. The details follow Supermemory: square corners, hairline
cards numbered 001, 002…, framed illustrations with corner marks, monospaced labels and
square buttons.

The logo is the "localbolo" wordmark on its own, with no symbol beside it. Wherever a single
icon is needed, such as the Buy button's icon box, the site uses the monogram: the "a" from the
wordmark, which is also the app icon, menu bar icon and favicon. Both are drawn in the text
color, black on light backgrounds and white on dark ones. The source SVGs are in `brand/` at the
root of the repository.

Black, white and one blue. **Every pixel is square**: the hero waveform, the section edges,
the background grids (`pixel-grid`) and Geist Pixel, the font used for accents. Type is
Geist for text and Geist Mono for labels. Colors, fonts and animations are defined with
`@theme` in `src/app/globals.css`.

Icons are pixel art written as text in `src/lib/pixel-icons.ts`: `#` is a pixel and `+` is a
blue accent pixel. Draw them on a small grid (9 × 9 for most) and render them at a whole
multiple of that size so every pixel stays sharp.

Motion respects reduced-motion settings: the waveform holds still, the demo shows its final
frame and the ASCII hover is off.

## Payments

LocalBolo is sold through [Dodo Payments](https://dodopayments.com), the merchant of record: Dodo
runs checkout, charges sales tax, and emails the receipt and a license key. Anyone can download
the app, but it only works once it's activated with a key. Every page is static except these,
which run on the server:

| Route | What it does |
| --- | --- |
| `/buy` | Creates a checkout session for the LocalBolo product and redirects to Dodo's checkout. Every Buy button links here. |
| `/purchase` | Where Dodo sends buyers back. It looks up the `payment_id` from the URL with Dodo, so a crafted link can't fake a confirmation, and reports the outcome. It shows nothing private, since anyone with the link sees it: license keys go out by email only. It's `noindex` and sends no referrer. |
| `/api/webhooks/dodo` | Verifies each webhook's signature and updates the [record of purchases](#purchases) when a payment succeeds, is refunded or disputed, or gets its license key. |
| `/download` | Redirects to the newest `LocalBolo.dmg` from the GitHub releases; `/download/v0.2.0` to a specific one. |
| `/appcast.xml` | The update feed the app's updater (Sparkle) checks, rebuilt every ten minutes from the GitHub releases. |

### Setting it up

1. In the Dodo dashboard, in **test mode**, create a product: LocalBolo for Mac, a one-time price
   of $49, tax category *Digital products*. Add a **License Key** entitlement with no expiry and
   an activation limit (for example 2 Macs), and an activation message such as "Download
   LocalBolo at https://localbolo.app/download and enter this key when it asks."
2. Create an API key, and a webhook pointing at `https://<your domain>/api/webhooks/dodo` with
   `payment.succeeded`, `refund.succeeded`, `license_key.created` and every `dispute.` event.
3. Copy `.env.local.example` to `.env.local` and fill in the API key, product ID, business ID and
   webhook secret. Buy with one of Dodo's test cards to try the whole flow; development builds
   of the app activate test-mode keys.
4. To go live, repeat steps 1 and 2 in **live mode** (products and keys don't carry over), then
   set the live values and `DODO_PAYMENTS_ENVIRONMENT=live_mode` for Production in the
   [Vercel project](#deploying).

Without the keys, the Buy buttons lead to a friendly "checkout isn't available" page, so the site
still builds and runs.

## Purchases

Everyone who buys LocalBolo gets a row in the `purchases` table in Supabase: name, email,
country, amount and currency, when they bought, Dodo's payment and customer IDs, and the ID of
their license key (never the key itself). `status` is `paid`, `partially_refunded`, `refunded`,
`disputed` (a chargeback is open) or `charged_back` (the bank returned the money, including
when a dispute expired without a response). Browse it in
Supabase's Table Editor, or query it in the SQL Editor:

```sql
select email, name, country, purchased_at, status from purchases order by purchased_at desc;
```

The webhook writes it, and Dodo stays the source of truth. Each event fetches the payment
fresh from Dodo and writes its current state, then looks again and writes again if the payment
changed meanwhile, so events that arrive twice, late, out of order or at the same time still
leave the right row. If a write fails, the webhook answers with an error and Dodo retries.

Only the website's server can read or write the table, with `SUPABASE_SECRET_KEY`: row level
security is on with no policies, so the publishable key sees nothing.

To change the table, add a migration to `supabase/migrations` and apply it to the project, with
the Supabase MCP server's `apply_migration` tool or the
[Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started):

```sh
npx supabase link --project-ref <project ref>
npx supabase db push
```

## Deploying

The site runs on [Vercel](https://vercel.com), in the `localbolo` project of the Thinking Sound
Lab team, connected to this repository:

- **Production** deploys every push to `main`. **Previews** deploy every pull request, behind
  Vercel's sign-in.
- The project's **Root Directory** is `apps/web` and its Node.js version is 24. Vercel installs
  the pnpm version pinned in `package.json` (`packageManager`) by itself.
- **Environment variables** go in the project's settings, not in files: everything in
  `.env.local.example`, with `GITHUB_RELEASES_TOKEN` optional. Mark the keys **Sensitive** so
  nobody can read them back.

`vercel env pull` writes the project's development variables to `.env.local`, replacing the file,
so copy anything you want to keep out of it first.

## Search engines

| Route | Source | Purpose |
| --- | --- | --- |
| `/robots.txt` | `app/robots.ts` | Allows crawling, except checkout, downloads and the update feed, and points to the sitemap |
| `/sitemap.xml` | `app/sitemap.ts` | Lists every page; add new pages here and to the footer |
| `/manifest.webmanifest` | `app/manifest.ts` | Name, icons and colors for browsers |
| `/opengraph-image` | `app/opengraph-image.tsx` | The link preview image |
| `/llms.txt` | `app/llms.txt/route.ts` | A plain-text summary for AI assistants |

Every page also gets a canonical URL and matching link previews from `pageMetadata()` in
`src/lib/metadata.ts`. The home page publishes schema.org data for the organization, the app
(with its price) and the FAQ as JSON-LD.

## Environments

| File | Used by | Contents |
| --- | --- | --- |
| `.env.development` | `pnpm dev` | `NEXT_PUBLIC_SITE_URL=http://localhost:3000` |
| `.env.production` | `pnpm build`, deployments | `NEXT_PUBLIC_SITE_URL=https://localbolo.app` |
| `.env.local` | Everything, git-ignored | Local overrides and secrets, such as the Dodo Payments and Supabase keys (see `.env.local.example`) |

`NEXT_PUBLIC_SITE_URL` is the base for absolute URLs: canonical links, the sitemap and link
previews.
