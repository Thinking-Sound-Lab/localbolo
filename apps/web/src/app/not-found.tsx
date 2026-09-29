import type { Metadata } from "next";
import Link from "next/link";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";

export const metadata: Metadata = {
  title: "Page not found",
};

export default function NotFound() {
  return (
    <>
      <SiteHeader />
      <main
        id="main"
        className="flex min-h-[70vh] flex-col items-center justify-center px-6 py-24 text-center pixel-grid"
      >
        <p className="font-pixel text-[9rem] leading-none text-blue sm:text-[14rem]">404</p>
        <h1 className="mt-6 text-3xl font-medium tracking-[-0.03em]">Nothing to transcribe here.</h1>
        <p className="mt-3 text-ink-soft">This page doesn&apos;t exist, or it has moved.</p>
        <Link
          href="/"
          className="mt-8 inline-flex h-12 items-center bg-ink px-5 font-mono text-xs tracking-[0.08em] text-white uppercase transition-colors hover:bg-blue"
        >
          Back to the home page
        </Link>
      </main>
      <SiteFooter />
    </>
  );
}
