/** A cell in a pixel grid, in grid units. */
export type Cell = { x: number; y: number };

/**
 * Returns a random number generator that produces the same sequence for a
 * given seed (mulberry32), so generated patterns render identically on the
 * server and in the browser.
 */
export function seededRandom(seed: number) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * SVG path data with a square in each cell, shrunk by `inset` on every side
 * (in cells) to leave a gap between neighbours. Keeping every square in one
 * path avoids hairline seams between touching squares.
 */
export function squaresPath(cells: Cell[], inset = 0) {
  const size = 1 - inset * 2;
  return cells.map(({ x, y }) => `M${x + inset} ${y + inset}h${size}v${size}h${-size}z`).join("");
}

/**
 * Pixel art drawn as rows of text: `#` is a pixel, `+` is an accent pixel,
 * anything else is empty.
 */
export type PixelArtRows = readonly string[];

export function parsePixelArt(rows: PixelArtRows) {
  const pixels: Cell[] = [];
  const accents: Cell[] = [];
  rows.forEach((row, y) => {
    [...row].forEach((character, x) => {
      if (character === "#") pixels.push({ x, y });
      if (character === "+") accents.push({ x, y });
    });
  });
  return {
    width: Math.max(...rows.map((row) => row.length)),
    height: rows.length,
    pixels,
    accents,
  };
}
