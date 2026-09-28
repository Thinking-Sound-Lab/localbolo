"use client";

import { useEffect, useRef } from "react";
import { cx } from "@/lib/cx";
import { usePrefersReducedMotion } from "@/lib/use-prefers-reduced-motion";

/** Distance between pixel centres, in CSS pixels. */
const spacing = 12;
/** How far around the pointer pixels grow, in CSS pixels. */
const pointerReach = 110;

type Pointer = { x: number; y: number } | null;

/**
 * A voice waveform on a grid of square pixels: pixels light up from the
 * middle row outwards as the "voice" gets louder, with the crest of each
 * column in the accent color. Pixels grow around the pointer. With reduced
 * motion it draws a single still frame.
 *
 * Pixels use the element's text color; the crests use `--pixel-accent`.
 */
export function PixelWave({ className }: { className?: string }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const prefersReducedMotion = usePrefersReducedMotion();

  useEffect(() => {
    const canvas = canvasRef.current;
    const context = canvas?.getContext("2d");
    if (!canvas || !context) return;

    const style = getComputedStyle(canvas);
    const colors = {
      pixel: style.color,
      accent: style.getPropertyValue("--pixel-accent").trim() || style.color,
    };

    let width = 0;
    let height = 0;
    let pointer: Pointer = null;
    let frame = 0;
    let isVisible = true;
    const startTime = performance.now();

    const render = (now: number) => {
      const seconds = prefersReducedMotion ? 4 : (now - startTime) / 1000;
      drawWave(context, width, height, seconds, pointer, colors);
    };

    const loop = (now: number) => {
      render(now);
      frame = requestAnimationFrame(loop);
    };

    const start = () => {
      cancelAnimationFrame(frame);
      if (prefersReducedMotion) render(performance.now());
      else if (isVisible) frame = requestAnimationFrame(loop);
    };

    const resize = () => {
      const bounds = canvas.getBoundingClientRect();
      const scale = window.devicePixelRatio || 1;
      width = bounds.width;
      height = bounds.height;
      canvas.width = Math.round(width * scale);
      canvas.height = Math.round(height * scale);
      context.setTransform(scale, 0, 0, scale, 0, 0);
      render(performance.now());
    };

    const trackPointer = (event: PointerEvent) => {
      const bounds = canvas.getBoundingClientRect();
      const x = event.clientX - bounds.left;
      const y = event.clientY - bounds.top;
      const isNear = y > -pointerReach && y < bounds.height + pointerReach;
      pointer = isNear ? { x, y } : null;
    };

    const resizeObserver = new ResizeObserver(resize);
    resizeObserver.observe(canvas);

    // Only animate while the wave is on screen.
    const visibilityObserver = new IntersectionObserver(([entry]) => {
      isVisible = entry.isIntersecting;
      if (isVisible) start();
      else cancelAnimationFrame(frame);
    });
    visibilityObserver.observe(canvas);

    // With reduced motion the wave is a still image, so it ignores the pointer.
    if (!prefersReducedMotion) window.addEventListener("pointermove", trackPointer, { passive: true });
    start();

    return () => {
      cancelAnimationFrame(frame);
      resizeObserver.disconnect();
      visibilityObserver.disconnect();
      window.removeEventListener("pointermove", trackPointer);
    };
  }, [prefersReducedMotion]);

  return <canvas ref={canvasRef} aria-hidden className={cx("block", className)} />;
}

/**
 * How loud the voice is at a horizontal position (0 to 1) and moment, from 0
 * to 1. Layered waves drift sideways like syllables and words, and the
 * signal fades out towards both edges.
 */
function loudness(position: number, seconds: number) {
  const syllables = 0.5 + 0.5 * Math.sin(position * 34 - seconds * 2.2);
  const words = 0.5 + 0.5 * Math.sin(position * 7.5 + seconds * 0.9);
  const breath = 0.5 + 0.5 * Math.sin(position * 2.3 - seconds * 0.45);
  const edges = Math.sin(Math.PI * position) ** 0.8;
  return edges * (0.08 + 0.92 * syllables * (0.35 + 0.65 * words) * (0.55 + 0.45 * breath));
}

function drawWave(
  context: CanvasRenderingContext2D,
  width: number,
  height: number,
  seconds: number,
  pointer: Pointer,
  colors: { pixel: string; accent: string },
) {
  context.clearRect(0, 0, width, height);

  const columns = Math.floor(width / spacing);
  const rows = Math.floor(height / spacing);
  if (columns < 2 || rows < 2) return;

  const left = (width - (columns - 1) * spacing) / 2;
  const top = (height - (rows - 1) * spacing) / 2;
  const middleRow = (rows - 1) / 2;

  for (let column = 0; column < columns; column++) {
    const x = left + column * spacing;
    // Rows lit on each side of the middle.
    const reach = loudness(column / (columns - 1), seconds) * (middleRow + 0.5);

    for (let row = 0; row < rows; row++) {
      const y = top + row * spacing;
      const distance = Math.abs(row - middleRow);
      const isLit = distance < reach;
      const isCrest = isLit && distance >= reach - 1;

      let size = isLit ? 6 : 2;
      if (pointer) {
        const closeness = 1 - Math.hypot(x - pointer.x, y - pointer.y) / pointerReach;
        if (closeness > 0) size += closeness * 3;
      }

      context.globalAlpha = isLit ? 1 : 0.25;
      context.fillStyle = isCrest ? colors.accent : colors.pixel;
      context.fillRect(Math.round(x - size / 2), Math.round(y - size / 2), Math.round(size), Math.round(size));
    }
  }

  context.globalAlpha = 1;
}
