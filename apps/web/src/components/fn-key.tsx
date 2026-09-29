import { PixelArt } from "@/components/pixel-art";
import { cx } from "@/lib/cx";
import { pixelIcons } from "@/lib/pixel-icons";

/** A Mac keyboard's fn / globe key. While pressed it sinks and its outline turns blue. */
export function FnKey({ isPressed = false, className }: { isPressed?: boolean; className?: string }) {
  return (
    <div
      aria-hidden
      className={cx(
        "flex size-14 flex-col justify-between rounded-lg border bg-white p-2 transition-all duration-150",
        isPressed
          ? "translate-y-[3px] border-blue text-blue shadow-[0_0_0_var(--color-blue)]"
          : "border-ink text-ink shadow-[0_3px_0_var(--color-ink)]",
        className,
      )}
    >
      <PixelArt art={pixelIcons.globe} className="size-[18px]" />
      <span className="self-end font-mono text-[11px] leading-none">fn</span>
    </div>
  );
}
