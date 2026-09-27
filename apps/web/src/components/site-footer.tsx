import Link from "next/link";
import { Logo } from "@/components/logo";
import { site } from "@/lib/site";

export function SiteFooter() {
  return (
    <footer className="border-t border-line">
      <div className="mx-auto flex max-w-6xl flex-col gap-6 px-6 py-10 text-sm text-ink-soft sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-2.5">
          <Logo className="h-4 w-8" />
          <span>
            {site.name} · Made for Mac
          </span>
        </div>
        <nav className="flex gap-6">
          <Link href="/privacy" className="transition hover:text-ink">
            Privacy
          </Link>
          <a href={site.repositoryUrl} className="transition hover:text-ink">
            GitHub
          </a>
          <a href={site.downloadUrl} className="transition hover:text-ink">
            Download
          </a>
        </nav>
      </div>
    </footer>
  );
}
