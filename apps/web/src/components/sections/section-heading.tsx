import type { ReactNode } from "react";
import { cx } from "@/lib/cx";

/** A small monospaced label with a blue pixel, used above headings. */
export function Eyebrow({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <p
      className={cx(
        "flex items-center gap-2.5 font-mono text-xs tracking-[0.14em] text-ink-faint uppercase",
        className,
      )}
    >
      <span aria-hidden className="size-2 bg-blue" />
      {children}
    </p>
  );
}

export function SectionHeading({
  eyebrow,
  title,
  children,
  className,
}: {
  eyebrow: string;
  title: ReactNode;
  children?: ReactNode;
  className?: string;
}) {
  return (
    <div className={cx("max-w-2xl", className)}>
      <Eyebrow>{eyebrow}</Eyebrow>
      <h2 className="mt-5 text-4xl leading-[0.98] font-medium tracking-[-0.04em] text-balance sm:text-6xl">
        {title}
      </h2>
      {children ? <p className="mt-5 text-lg text-pretty text-ink-soft">{children}</p> : null}
    </div>
  );
}
