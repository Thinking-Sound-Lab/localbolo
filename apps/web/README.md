# LocalBolo website

The marketing site for LocalBolo, built with Next.js (App Router) and Tailwind CSS.

```sh
pnpm install
pnpm dev     # http://localhost:3000
pnpm build   # production build
pnpm lint
```

## Structure

```
src/
  app/                   Routes: home, support, changelog, privacy, terms, refunds,
                         plus icons and the files search engines read
    buy/route.ts         Starts a Dodo Payments checkout
    purchase/page.tsx    Where buyers land after checkout
    api/webhooks/dodo/   Verified Dodo Payments webhooks
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
    logo.tsx             The "localbolo" wordmark, LocalBolo's logo
    pill.tsx             The dictation pill, matching the Mac app's design
  lib/
    site.ts              Name, price, refund window, contact, purchase link, footer links
    dodo.ts              The Dodo Payments client and product
    models.ts            Speech model list (mirrors the Mac app)
    faq.ts               FAQ, shown on the page and published as structured data
    wordmark.ts          The wordmark as one SVG path, traced from the logo artwork
    pixel-icons.ts       Every pixel-art icon, drawn as text, including a pixel wordmark
    metadata.ts          Per-page title, canonical URL and link previews
    structured-data.ts   schema.org data for the home page
```

## Design

The layout follows dictation apps like Wispr Flow and Superwhisper: a centered hero with the
product demo, the apps it works in, then speed, how it works, features, privacy, models,
pricing, FAQ and a full footer. The details follow Supermemory: square corners, hairline
cards numbered 001, 002…, framed illustrations with corner marks, monospaced labels and
square buttons.

The logo is the "localbolo" wordmark on its own, with no symbol beside it. It's drawn in the
text color, black on light backgrounds and white on dark ones; `docs/images/wordmark.svg` and
`wordmark-white.svg` are standalone copies.

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
runs checkout, charges sales tax, and emails the receipt and the download. Every page is static
except these, which run on the server:

| Route | What it does |
| --- | --- |
| `/buy` | Creates a checkout session for the LocalBolo product and redirects to Dodo's checkout. Every Buy button links here. |
| `/purchase` | Where Dodo sends buyers back. It looks up the `payment_id` from the URL with Dodo, so a crafted link can't fake a confirmation, and reports the outcome. It shows nothing private, since anyone with the link sees it: license keys go out by email only. It's `noindex` and sends no referrer. |
| `/api/webhooks/dodo` | Verifies each webhook's signature and logs sales, refunds and disputes (IDs and amounts only). |

### Setting it up

1. In the Dodo dashboard, in **test mode**, create a product: LocalBolo for Mac, a one-time price
   of $49, tax category *Digital products*. Attach the disk image under **Digital product
   delivery** so buyers get the download by email.
2. Create an API key, and a webhook pointing at `https://<your domain>/api/webhooks/dodo` with at
   least `payment.succeeded`, `payment.failed`, `refund.succeeded` and `dispute.opened`.
3. Copy `.env.local.example` to `.env.local` and fill in the API key, product ID and webhook
   secret. Buy with one of Dodo's test cards to try the whole flow.
4. To go live, repeat steps 1 and 2 in **live mode** (products and keys don't carry over), set
   the live values and `DODO_PAYMENTS_ENVIRONMENT=live_mode` in your hosting provider, and
   deploy.

Without the keys, the Buy buttons lead to a friendly "checkout isn't available" page, so the site
still builds and runs.

## Search engines

| Route | Source | Purpose |
| --- | --- | --- |
| `/robots.txt` | `app/robots.ts` | Allows crawling, except checkout and webhooks, and points to the sitemap |
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
| `.env.local` | Everything, git-ignored | Local overrides and secrets, such as the Dodo Payments keys (see `.env.local.example`) |

`NEXT_PUBLIC_SITE_URL` is the base for absolute URLs: canonical links, the sitemap and link
previews.
