import type { ReactNode } from "react";
import { CornerMarks } from "@/components/buy-button";
import { cx } from "@/lib/cx";

/**
 * A square card with a hairline border: a title, an optional monospaced
 * subtitle, and an optional number in the top-right corner (001, 002, …).
 */
export function Card({
  title,
  subtitle,
  index,
  children,
  className,
}: {
  title: ReactNode;
  subtitle?: string;
  index?: number;
  children?: ReactNode;
  className?: string;
}) {
  return (
    <div className={cx("flex flex-col border border-line bg-white p-6", className)}>
      <div className="flex items-start justify-between gap-4">
        <div>
          <h3 className="text-lg leading-snug font-medium tracking-[-0.02em]">{title}</h3>
          {subtitle ? (
            <p className="mt-1 font-mono text-[11px] tracking-[0.1em] text-ink-faint uppercase">{subtitle}</p>
          ) : null}
        </div>
        {index !== undefined ? <CardIndex index={index} /> : null}
      </div>
      {children}
    </div>
  );
}

/** A card's number, padded to three digits. */
export function CardIndex({ index, className }: { index: number; className?: string }) {
  return (
    <span className={cx("shrink-0 font-mono text-[11px] text-ink-faint", className)}>
      {String(index).padStart(3, "0")}
    </span>
  );
}

/** An illustration area: a faint pixel grid with corner marks, like a viewfinder. */
export function Frame({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className={cx("relative grid place-items-center pixel-grid", className)}>
      <CornerMarks className="border-ink/30" />
      {children}
    </div>
  );
}
