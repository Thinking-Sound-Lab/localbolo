"use client";

import { useEffect, useRef, type ReactNode } from "react";
import { usePrefersReducedMotion } from "@/lib/use-prefers-reduced-motion";

/** Characters a scrambled letter cycles through. */
const glyphs = "@#%&$*+=?/<>~:;01";
/** How close the pointer has to come to scramble a letter, in CSS pixels. */
const reach = 70;
/** How often a scrambled letter shows a new character, in milliseconds. */
const glyphInterval = 70;

/**
 * Wraps text written with `AsciiText`. Letters the mouse pointer passes
 * dissolve into cycling ASCII characters, then settle back a moment after it
 * moves on or comes to rest. It does nothing for touch input or with reduced
 * motion.
 */
export function AsciiHover({ children, className }: { children: ReactNode; className?: string }) {
  const containerRef = useRef<HTMLDivElement>(null);
  const prefersReducedMotion = usePrefersReducedMotion();

  useEffect(() => {
    const container = containerRef.current;
    if (!container || prefersReducedMotion) return;

    const letters = [...container.querySelectorAll<HTMLElement>("[data-letter]")];
    /** Scrambled letters, with when each settles back and when it last changed. */
    const scrambled = new Map<HTMLElement, { settleAt: number; changedAt: number }>();
    /** Where the pointer moved to since the last frame, if it moved. */
    let pointer: { x: number; y: number } | null = null;
    let frame = 0;

    // Letters are measured only after the pointer moves, and the loop stops
    // once every letter has settled, so a resting pointer costs nothing.
    const tick = (now: number) => {
      if (pointer) {
        for (const letter of letters) {
          const bounds = letter.getBoundingClientRect();
          const distance = Math.hypot(
            bounds.left + bounds.width / 2 - pointer.x,
            bounds.top + bounds.height / 2 - pointer.y,
          );
          if (distance > reach) continue;
          // Letters closer to the pointer stay scrambled a little longer.
          const settleAt = now + 150 + (1 - distance / reach) * 250 + Math.random() * 300;
          const state = scrambled.get(letter);
          if (state) state.settleAt = Math.max(state.settleAt, settleAt);
          else scrambled.set(letter, { settleAt, changedAt: 0 });
        }
        pointer = null;
      }

      for (const [letter, state] of scrambled) {
        if (now >= state.settleAt) {
          scrambled.delete(letter);
          restore(letter);
        } else if (now - state.changedAt >= glyphInterval) {
          scramble(letter);
          state.changedAt = now;
        }
      }

      frame = scrambled.size > 0 ? requestAnimationFrame(tick) : 0;
    };

    const trackPointer = (event: PointerEvent) => {
      if (event.pointerType !== "mouse") return;
      pointer = { x: event.clientX, y: event.clientY };
      if (!frame) frame = requestAnimationFrame(tick);
    };

    container.addEventListener("pointermove", trackPointer);

    return () => {
      cancelAnimationFrame(frame);
      container.removeEventListener("pointermove", trackPointer);
      scrambled.forEach((_, letter) => restore(letter));
    };
  }, [prefersReducedMotion]);

  return (
    <div ref={containerRef} className={className}>
      {children}
    </div>
  );
}

/**
 * Splits text into letters that `AsciiHover` can scramble. Spaces stay plain
 * text, so lines still wrap between words.
 */
export function AsciiText({ text }: { text: string }) {
  return [...text].map((character, index) =>
    character === " " ? (
      " "
    ) : (
      <span key={index} data-letter="">
        {character}
      </span>
    ),
  );
}

function scramble(letter: HTMLElement) {
  letter.dataset.glyph = glyphs[Math.floor(Math.random() * glyphs.length)];
  // About one in four glyphs is blue.
  if (Math.random() < 0.25) letter.dataset.glyphAccent = "";
  else delete letter.dataset.glyphAccent;
}

function restore(letter: HTMLElement) {
  delete letter.dataset.glyph;
  delete letter.dataset.glyphAccent;
}
