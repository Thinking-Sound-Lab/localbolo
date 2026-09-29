import { cx } from "@/lib/cx";
import { monogram } from "@/lib/monogram";
import { wordmark } from "@/lib/wordmark";

/*
 * LocalBolo's two marks, drawn in the text color so they work on light and
 * dark backgrounds. Set their height; the width follows.
 */

/** The logo: the "localbolo" wordmark. */
export function Logo({ className }: { className?: string }) {
  return (
    <svg
      viewBox={wordmark.viewBox}
      role="img"
      aria-label="LocalBolo"
      className={cx("h-6 w-auto fill-current", className)}
    >
      <path fillRule="evenodd" d={wordmark.path} />
    </svg>
  );
}

/** The monogram, the "a" from the wordmark, for wherever a single icon is needed. */
export function Monogram({ className }: { className?: string }) {
  return (
    <svg viewBox={monogram.viewBox} aria-hidden className={cx("h-4 w-auto fill-current", className)}>
      <path fillRule="evenodd" d={monogram.path} />
    </svg>
  );
}
