import Link from "next/link";
import { Logo } from "@/components/logo";
import { site } from "@/lib/site";

const links = [
  { label: "How it works", href: "/#how-it-works" },
  { label: "Pricing", href: "/#pricing" },
  { label: "FAQ", href: "/#faq" },
  { label: "Privacy policy", href: "/privacy" },
];

/** The footer sits on black, continuing the final call to action. */
export function SiteFooter() {
  return (
    <footer className="bg-ink text-white">
      <div className="mx-auto flex max-w-6xl flex-col gap-8 border-t border-white/10 px-6 py-10 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-3">
          <Logo className="text-white" accentClassName="fill-blue-soft" />
          <span className="font-mono text-xs tracking-wide text-white/60">
            © {new Date().getFullYear()} {site.company}
          </span>
        </div>
        <nav aria-label="Footer" className="flex flex-wrap gap-x-6 gap-y-2 text-sm text-white/60">
          {links.map((link) => (
            <Link key={link.href} href={link.href} className="transition-colors hover:text-white">
              {link.label}
            </Link>
          ))}
        </nav>
      </div>
    </footer>
  );
}
