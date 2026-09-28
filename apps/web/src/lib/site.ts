/** Site-wide copy and links, kept in one place so pages stay consistent. */
export const site = {
  name: "LocalBolo",
  tagline: "Private dictation for Mac",
  description:
    "Hold fn, speak, and let go. LocalBolo is private dictation for Mac: speech to text that runs entirely on your device and types into any app.",
  company: "Thinking Sound Lab",
  /** Base URL for absolute links such as link previews. Set per environment in .env.development / .env.production. */
  url: process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000",
  /** Where every Buy button goes. Point this at the checkout page once payments are set up. */
  purchaseUrl: "https://github.com/Thinking-Sound-Lab/localbolo/releases/latest",
  price: {
    amount: 49,
    currency: "USD",
    label: "$49",
  },
  requirements: "macOS 15 or later · Apple Silicon",
} as const;
