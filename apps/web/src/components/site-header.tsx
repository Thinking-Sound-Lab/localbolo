import Link from "next/link";
import { DownloadButton } from "@/components/download-button";
import { Logo } from "@/components/logo";
import { site } from "@/lib/site";

const navigation = [
  { label: "How it works", href: "/#how-it-works" },
  { label: "Models", href: "/#models" },
  { label: "Privacy", href: "/#privacy" },
  { label: "FAQ", href: "/#faq" },
];

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-50 border-b border-line/60 bg-paper/80 backdrop-blur-lg">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6">
        <Link href="/" className="flex items-center gap-2.5 text-[17px] font-semibold tracking-tight">
          <Logo />
          {site.name}
        </Link>
        <nav className="hidden items-center gap-8 text-sm text-ink-soft md:flex">
          {navigation.map((item) => (
            <Link key={item.href} href={item.href} className="transition hover:text-ink">
              {item.label}
            </Link>
          ))}
        </nav>
        <DownloadButton size="sm" />
      </div>
    </header>
  );
}
