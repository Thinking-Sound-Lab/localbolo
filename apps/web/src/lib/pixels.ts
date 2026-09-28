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
 * SVG path data with a square in each cell. Keeping every square in one path
 * avoids hairline seams between neighbours.
 */
export function squaresPath(cells: Cell[]) {
  return cells.map(({ x, y }) => `M${x} ${y}h1v1h-1z`).join("");
}

/** SVG path data with a dot in each cell. */
export function dotsPath(cells: Cell[], radius = 0.38) {
  const diameter = radius * 2;
  return cells
    .map(
      ({ x, y }) =>
        `M${x + 0.5 - radius} ${y + 0.5}a${radius} ${radius} 0 1 0 ${diameter} 0a${radius} ${radius} 0 1 0 ${-diameter} 0z`,
    )
    .join("");
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
