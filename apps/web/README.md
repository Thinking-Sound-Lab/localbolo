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
  app/                 Routes, root layout, icons and the Open Graph image
  components/
    sections/          One file per landing page section
    hero-demo.tsx      Animated dictation demo (client component)
    pill.tsx           The dictation pill, matching the Mac app's design
  lib/
    site.ts            Name, copy, download and repository links
    models.ts          Speech model list (mirrors the Mac app)
```

Design tokens (colors, fonts, animations) are defined with `@theme` in
`src/app/globals.css`.

## Environments

| File | Used by | Contents |
| --- | --- | --- |
| `.env.development` | `pnpm dev` | `NEXT_PUBLIC_SITE_URL=http://localhost:3000` |
| `.env.production` | `pnpm build`, deployments | `NEXT_PUBLIC_SITE_URL=https://localbolo.app` |
| `.env.local` | Everything, git-ignored | Local overrides and secrets |

`NEXT_PUBLIC_SITE_URL` is the base for absolute URLs such as link previews.
