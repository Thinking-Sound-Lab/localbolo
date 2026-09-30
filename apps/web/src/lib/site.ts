/** Site-wide copy and links, kept in one place so pages stay consistent. */
export const site = {
  name: "LocalBolo",
  tagline: "Private dictation for Mac",
  description:
    "Hold fn, speak, and let go. LocalBolo is private dictation for Mac: speech to text that runs entirely on your device and types into any app.",
  company: "Thinking Sound Lab",
  /** The legal entity that sells LocalBolo, as it appears in the policies. */
  legalName: "Thinking Sound Lab Private Limited",
  supportEmail: "abhishek@ThinkingSoundLab.com",
  /** Base URL for absolute links such as link previews. Set per environment in .env.development / .env.production. */
  url: process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000",
  /** Where every Buy button goes: starts a Dodo Payments checkout (app/buy/route.ts). */
  purchaseUrl: "/buy",
  /** The newest version of the Mac app (app/download). It asks for a license key before it works. */
  downloadUrl: "/download",
  price: {
    amount: 49,
    currency: "USD",
    label: "$49",
  },
  /** How long after buying a customer can ask for a full refund. */
  refundDays: 7,
  /** How many Macs one license key can be active on at a time. Keep in step with the activation limit in Dodo. */
  macsPerLicense: 2,
  /** Where buyers look up a lost license key (app/license: Dodo's customer portal). */
  findLicenseUrl: "/license",
  requirements: "macOS 15 or later · Apple Silicon",
} as const;

/** Links in the footer, by column. Every one must lead to a real page or section. */
export const footerLinks = [
  {
    title: "Product",
    links: [
      { label: "How it works", href: "/#how-it-works" },
      { label: "Cleanup", href: "/#cleanup" },
      { label: "Features", href: "/#features" },
      { label: "Models", href: "/#models" },
      { label: "Pricing", href: "/#pricing" },
    ],
  },
  {
    title: "Support",
    links: [
      { label: "Help & contact", href: "/support" },
      { label: "Find my license key", href: "/license", prefetch: false },
      { label: "System requirements", href: "/support#requirements" },
      { label: "FAQ", href: "/#faq" },
      { label: "Changelog", href: "/changelog" },
    ],
  },
  {
    title: "Legal",
    links: [
      { label: "Privacy policy", href: "/privacy" },
      { label: "Terms of service", href: "/terms" },
      { label: "Refund policy", href: "/refunds" },
    ],
  },
] as const;
