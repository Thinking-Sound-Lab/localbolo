import { PixelArt } from "@/components/pixel-art";
import { cx } from "@/lib/cx";
import { pixelIcons } from "@/lib/pixel-icons";
import { site } from "@/lib/site";

const sizes = {
  sm: "h-9 gap-2 px-4 text-sm",
  lg: "h-12 gap-2.5 px-6 text-base",
};

const tones = {
  /** For light backgrounds. */
  dark: "bg-ink text-white hover:bg-blue focus-visible:outline-ink",
  /** For dark or blue backgrounds. */
  light: "bg-white text-ink hover:bg-blue-pale focus-visible:outline-white",
};

/** The call to action: buy LocalBolo. */
export function BuyButton({
  size = "lg",
  tone = "dark",
  className,
}: {
  size?: keyof typeof sizes;
  tone?: keyof typeof tones;
  className?: string;
}) {
  return (
    <a
      href={site.purchaseUrl}
      className={cx(
        "group inline-flex items-center rounded-full font-medium transition-colors focus-visible:outline-2 focus-visible:outline-offset-2",
        sizes[size],
        tones[tone],
        className,
      )}
    >
      Buy for {site.price.label}
      <PixelArt
        art={pixelIcons.arrow}
        className="size-[14px] transition-transform group-hover:translate-x-0.5"
      />
    </a>
  );
}
