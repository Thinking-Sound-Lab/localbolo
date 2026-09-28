import { PixelArt } from "@/components/pixel-art";
import { cx } from "@/lib/cx";
import { pixelIcons } from "@/lib/pixel-icons";

/**
 * LocalBolo's mark: a pixel waveform with a blue centre. The default size is
 * three screen pixels per art pixel, which keeps it crisp.
 */
export function Logo({ className, accentClassName }: { className?: string; accentClassName?: string }) {
  return (
    <PixelArt
      art={pixelIcons.logo}
      className={cx("h-[21px] w-[27px]", className)}
      accentClassName={accentClassName}
    />
  );
}
