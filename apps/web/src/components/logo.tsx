import { cx } from "@/lib/cx";
import { wordmark } from "@/lib/wordmark";

/**
 * LocalBolo's logo, the "localbolo" wordmark. It's drawn in the text color,
 * so it works on light and dark backgrounds. Set its height; the width
 * follows.
 */
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
