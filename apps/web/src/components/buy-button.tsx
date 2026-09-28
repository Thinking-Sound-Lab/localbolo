import type { ReactNode } from "react";
import { PixelArt } from "@/components/pixel-art";
import { cx } from "@/lib/cx";
import { pixelIcons } from "@/lib/pixel-icons";
import { site } from "@/lib/site";

const sizes = {
  sm: { button: "h-9", icon: "w-9", label: "px-3 text-[11px]" },
  lg: { button: "h-12", icon: "w-12", label: "px-5 text-xs" },
};

const tones = {
  /** Blue, for light backgrounds. */
  blue: {
    button: "border-blue bg-blue text-white hover:border-blue-deep hover:bg-blue-deep",
    icon: "bg-white text-blue",
  },
  /** White, for dark or blue backgrounds. */
  white: {
    button: "border-white bg-white text-ink hover:bg-blue-pale",
    icon: "bg-blue text-white",
  },
};

/**
 * The call to action: buy LocalBolo. A square button with an arrow in a box
 * at its start and a monospaced label.
 */
export function BuyButton({
  size = "lg",
  tone = "blue",
  className,
}: {
  size?: keyof typeof sizes;
  tone?: keyof typeof tones;
  className?: string;
}) {
  return (
    <a
      href={site.purchaseUrl}
      rel="nofollow"
      className={cx(
        "group inline-flex items-stretch border font-mono tracking-[0.08em] uppercase transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue",
        sizes[size].button,
        tones[tone].button,
        className,
      )}
    >
      <span className={cx("grid shrink-0 place-items-center", sizes[size].icon, tones[tone].icon)}>
        <PixelArt
          art={pixelIcons.arrow}
          className="size-[14px] transition-transform group-hover:translate-x-0.5"
        />
      </span>
      <span className={cx("flex items-center whitespace-nowrap", sizes[size].label)}>
        Buy for {site.price.label}
      </span>
    </a>
  );
}

/**
 * A quieter square link, with corner marks, for secondary actions such as
 * "See how it works".
 */
export function SecondaryLink({
  href,
  children,
  className,
}: {
  href: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <a
      href={href}
      className={cx(
        "relative inline-flex h-12 items-center bg-blue-pale px-5 font-mono text-xs tracking-[0.08em] text-ink uppercase transition-colors hover:bg-[#dde2ff] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue",
        className,
      )}
    >
      <CornerMarks />
      {children}
    </a>
  );
}

/** Four small L-shaped marks in the corners of the nearest positioned parent. */
export function CornerMarks({ className = "border-blue/50" }: { className?: string }) {
  const corner = cx("pointer-events-none absolute size-2", className);
  return (
    <span aria-hidden>
      <span className={cx(corner, "top-0 left-0 border-t border-l")} />
      <span className={cx(corner, "top-0 right-0 border-t border-r")} />
      <span className={cx(corner, "bottom-0 left-0 border-b border-l")} />
      <span className={cx(corner, "right-0 bottom-0 border-r border-b")} />
    </span>
  );
}
