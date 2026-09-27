import type { ReactNode } from "react";
import { cx } from "@/lib/cx";

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
      <p className="text-sm font-medium tracking-wide text-ember uppercase">{eyebrow}</p>
      <h2 className="mt-3 font-display text-5xl leading-[1.02] tracking-tight text-balance sm:text-6xl">{title}</h2>
      {children ? <p className="mt-5 text-lg text-ink-soft">{children}</p> : null}
    </div>
  );
}
