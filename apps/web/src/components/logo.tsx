import { cx } from "@/lib/cx";

/** LocalBolo's mark: the dictation pill with a waveform. */
export function Logo({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 40 20" className={cx("h-5 w-10", className)} aria-hidden>
      <rect width="40" height="20" rx="10" className="fill-ink" />
      {[
        [11, 4],
        [15, 7],
        [19, 9],
        [23, 7],
        [27, 5],
      ].map(([x, halfHeight]) => (
        <rect
          key={x}
          x={x - 1}
          y={10 - halfHeight}
          width="2"
          height={halfHeight * 2}
          rx="1"
          className="fill-paper"
        />
      ))}
    </svg>
  );
}
