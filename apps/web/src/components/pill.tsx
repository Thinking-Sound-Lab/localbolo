import type { ReactNode } from "react";
import { cx } from "@/lib/cx";

export type PillState = "resting" | "listening" | "transcribing";

const barCount = 11;

/** Bars are tallest in the middle, like the Mac app's waveform. */
const barHeights = Array.from({ length: barCount }, (_, index) => {
  const position = index / (barCount - 1);
  return 0.35 + 0.65 * Math.sin(position * Math.PI);
});

const labels: Record<PillState, string> = {
  resting: "Dictation ready",
  listening: "Listening",
  transcribing: "Transcribing",
};

/**
 * The dictation pill as it appears in the Mac app: a small resting capsule
 * that grows into a black pill showing the target app's icon and a live
 * waveform.
 */
export function Pill({ state, icon }: { state: PillState; icon?: ReactNode }) {
  const isActive = state !== "resting";

  return (
    <div
      role="img"
      aria-label={labels[state]}
      className={cx(
        "flex items-center overflow-hidden rounded-full border transition-all duration-500 ease-spring",
        isActive
          ? "h-[34px] w-[114px] gap-2 border-white/15 bg-black/90 pr-3 pl-1.5 shadow-[0_10px_28px_-6px_rgba(0,0,0,0.45)]"
          : "h-2 w-10 gap-0 border-white/40 bg-black/45 px-0",
      )}
    >
      <div
        className={cx(
          "size-5 shrink-0 transition-opacity duration-300",
          isActive ? "opacity-100 delay-150" : "opacity-0",
        )}
      >
        {icon}
      </div>
      <div
        className={cx(
          "flex h-[18px] items-center gap-[3px] transition-opacity duration-300",
          isActive ? "opacity-100 delay-150" : "opacity-0",
        )}
      >
        {barHeights.map((height, index) => (
          <span
            key={index}
            className={cx(
              "w-[3px] rounded-full bg-white",
              state === "listening" && "motion-safe:animate-wave",
              state === "transcribing" && "opacity-55 motion-safe:animate-ripple",
            )}
            style={{
              height: `${height * 18}px`,
              animationDelay:
                state === "transcribing" ? `${index * 0.08}s` : `${-index * 0.17}s`,
              animationDuration:
                state === "listening" ? `${0.45 + (index % 4) * 0.12}s` : undefined,
            }}
          />
        ))}
      </div>
    </div>
  );
}
