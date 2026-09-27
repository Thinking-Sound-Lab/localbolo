import type { ReactNode } from "react";
import { cx } from "@/lib/cx";

/** Generic app icons for the product demo. */
function AppTile({ className, children }: { className: string; children: ReactNode }) {
  return (
    <div
      className={cx(
        "grid size-full place-items-center rounded-[24%] shadow-[inset_0_1px_0_rgba(255,255,255,0.35)]",
        className,
      )}
    >
      {children}
    </div>
  );
}

const glyph = "w-[60%] fill-none stroke-white stroke-2 [stroke-linecap:round] [stroke-linejoin:round]";

export function MailIcon() {
  return (
    <AppTile className="bg-linear-to-b from-sky-400 to-blue-600">
      <svg viewBox="0 0 24 24" className={glyph} aria-hidden>
        <rect x="3" y="5.5" width="18" height="13" rx="2" />
        <path d="m4 7 8 6 8-6" />
      </svg>
    </AppTile>
  );
}

export function ChatIcon() {
  return (
    <AppTile className="bg-linear-to-b from-violet-400 to-fuchsia-600">
      <svg viewBox="0 0 24 24" className={glyph} aria-hidden>
        <path d="M20 12a7.5 7.5 0 0 1-11 6.6L4.5 20l1.3-4A7.5 7.5 0 1 1 20 12Z" />
      </svg>
    </AppTile>
  );
}

export function NotesIcon() {
  return (
    <AppTile className="bg-linear-to-b from-amber-300 to-orange-500">
      <svg viewBox="0 0 24 24" className={glyph} aria-hidden>
        <path d="M7 7h10M7 12h10M7 17h6" />
      </svg>
    </AppTile>
  );
}

export function CodeIcon() {
  return (
    <AppTile className="bg-linear-to-b from-slate-600 to-slate-900">
      <svg viewBox="0 0 24 24" className={glyph} aria-hidden>
        <path d="m9 8-4 4 4 4M15 8l4 4-4 4" />
      </svg>
    </AppTile>
  );
}

export function BrowserIcon() {
  return (
    <AppTile className="bg-linear-to-b from-emerald-400 to-teal-600">
      <svg viewBox="0 0 24 24" className={glyph} aria-hidden>
        <circle cx="12" cy="12" r="8" />
        <path d="M4 12h16M12 4c2.5 2.5 2.5 13.5 0 16M12 4c-2.5 2.5-2.5 13.5 0 16" />
      </svg>
    </AppTile>
  );
}
