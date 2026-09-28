# LocalBolo website

The marketing site for LocalBolo, built with Next.js (App Router) and Tailwind CSS.

```sh
pnpm install
pnpm dev     # http://localhost:3000
pnpm build   # production build, fully static
pnpm lint
```

## Structure

```
src/
  app/                   Routes, root layout, icons, and the files search engines read
  components/
    sections/            One file per landing page section
    hero-demo.tsx        Animated dictation demo (client component)
    dot-wave.tsx         The hero's dot-matrix voice waveform (canvas, client component)
    pixel-art.tsx        Draws pixel art from rows of text
    pixel-edge.tsx       Pixel "terrain" where a light section meets a dark one
    pixel-cascade.tsx    Pixels piling up from the corners of the final call to action
    pill.tsx             The dictation pill, matching the Mac app's design
  lib/
    site.ts              Name, copy, price and purchase link
    models.ts            Speech model list (mirrors the Mac app)
    faq.ts               FAQ, shown on the page and published as structured data
    pixel-icons.ts       Every pixel-art icon, drawn as text
    metadata.ts          Per-page title, canonical URL and link previews
    structured-data.ts   schema.org data for the home page
```

## Design

Black, white and one blue. Voice is drawn as round dots and text as square pixels, which is why
the hero waveform is a dot matrix and the section edges are square pixels. Type is Geist for
text, Geist Mono for labels, and Geist Pixel for accents; its `pixel-dots` utility switches the
pixels to round dots. Colors, fonts and animations are defined with `@theme` in
`src/app/globals.css`.

Icons are pixel art written as text in `src/lib/pixel-icons.ts`: `#` is a pixel and `+` is a
blue accent pixel. Draw them on a small grid (9 × 9 for most) and render them at a whole
multiple of that size so every pixel stays sharp.

## Search engines

| Route | Source | Purpose |
| --- | --- | --- |
| `/robots.txt` | `app/robots.ts` | Allows crawling and points to the sitemap |
| `/sitemap.xml` | `app/sitemap.ts` | Lists every page; add new pages here |
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
| `.env.local` | Everything, git-ignored | Local overrides and secrets |

`NEXT_PUBLIC_SITE_URL` is the base for absolute URLs: canonical links, the sitemap and link
previews.
