import { cx } from "@/lib/cx";

/** A Mac keyboard's fn / globe key, drawn in CSS. */
export function FnKey({ isPressed = false, className }: { isPressed?: boolean; className?: string }) {
  return (
    <div
      aria-hidden
      className={cx(
        "flex size-14 flex-col justify-between rounded-[10px] border border-black/10 bg-linear-to-b from-white to-[#ecebe8] p-2 text-ink transition-all duration-150",
        isPressed
          ? "translate-y-0.5 shadow-[0_1px_0_#c9c6bf,0_2px_4px_rgba(0,0,0,0.12)]"
          : "shadow-[0_3px_0_#c9c6bf,0_6px_12px_rgba(0,0,0,0.15)]",
        className,
      )}
    >
      <svg viewBox="0 0 24 24" className="size-3.5 fill-none stroke-current stroke-[1.6]">
        <circle cx="12" cy="12" r="9" />
        <path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18" />
      </svg>
      <span className="self-end text-[11px] leading-none font-medium">fn</span>
    </div>
  );
}
