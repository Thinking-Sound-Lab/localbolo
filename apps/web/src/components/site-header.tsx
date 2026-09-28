import Link from "next/link";
import { BuyButton } from "@/components/buy-button";
import { Logo } from "@/components/logo";
import { site } from "@/lib/site";

const navigation = [
  { label: "How it works", href: "/#how-it-works" },
  { label: "Features", href: "/#features" },
  { label: "Privacy", href: "/#privacy" },
  { label: "Pricing", href: "/#pricing" },
  { label: "Support", href: "/support" },
];

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-50 border-b border-line bg-white/90 backdrop-blur-lg">
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:absolute focus:top-3 focus:left-3 focus:bg-ink focus:px-3 focus:py-2 focus:text-sm focus:text-white"
      >
        Skip to content
      </a>
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-6 px-6">
        <Link href="/" className="flex items-center gap-3 text-[17px] font-semibold tracking-tight">
          <Logo />
          {site.name}
        </Link>
        <nav aria-label="Main" className="hidden items-center gap-8 text-sm text-ink-soft md:flex">
          {navigation.map((item) => (
            <Link key={item.href} href={item.href} className="transition-colors hover:text-ink">
              {item.label}
            </Link>
          ))}
        </nav>
        <BuyButton size="sm" />
      </div>
    </header>
  );
}
