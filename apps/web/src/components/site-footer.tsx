import Link from "next/link";
import { BuyButton } from "@/components/buy-button";
import { Logo } from "@/components/logo";
import { PixelArt } from "@/components/pixel-art";
import { pixelIcons } from "@/lib/pixel-icons";
import { footerLinks, site } from "@/lib/site";

/** The footer sits on black, continuing the final call to action. */
export function SiteFooter() {
  return (
    <footer className="overflow-hidden bg-ink text-white">
      <div className="mx-auto max-w-6xl px-6">
        <div className="grid gap-12 border-t border-white/10 py-16 md:grid-cols-[1.4fr_1fr_1fr_1fr]">
          <div>
            <Link href="/" className="inline-block transition-opacity hover:opacity-70">
              <Logo className="h-7 text-white" />
            </Link>
            <p className="mt-4 max-w-xs text-sm text-white/60">
              Private dictation for Mac. Your voice is turned into text on your Mac and never leaves
              it.
            </p>
            <p className="mt-4 font-mono text-[11px] tracking-[0.1em] text-white/45 uppercase">
              {site.requirements}
            </p>
            <BuyButton size="sm" tone="white" className="mt-7" />
          </div>

          {footerLinks.map((column) => (
            <nav key={column.title} aria-label={column.title}>
              <h2 className="font-mono text-[11px] tracking-[0.12em] text-white/45 uppercase">
                {column.title}
              </h2>
              <ul className="mt-4 space-y-3 text-sm">
                {column.links.map((link) => (
                  <li key={link.href}>
                    <Link
                      href={link.href}
                      prefetch={"prefetch" in link ? link.prefetch : undefined}
                      className="text-white/75 transition-colors hover:text-white"
                    >
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </nav>
          ))}
        </div>

        <div className="flex flex-col gap-4 border-t border-white/10 py-6 text-xs text-white/55 sm:flex-row sm:items-center sm:justify-between">
          <span>
            © {new Date().getFullYear()} {site.legalName}
          </span>
          <div className="flex items-center gap-5">
            <span className="flex items-center gap-2">
              <span aria-hidden className="size-1.5 bg-blue-soft" />
              Your audio never leaves your Mac
            </span>
            <a href="#top" className="transition-colors hover:text-white">
              Back to top ↑
            </a>
          </div>
        </div>
      </div>

      {/* The wordmark, large and in square pixels, bleeding off the bottom edge. */}
      <div className="mx-auto -mb-[3%] max-w-6xl px-6 pt-4">
        <PixelArt art={pixelIcons.wordmark} className="h-auto w-full text-white/[0.07]" />
      </div>
    </footer>
  );
}
