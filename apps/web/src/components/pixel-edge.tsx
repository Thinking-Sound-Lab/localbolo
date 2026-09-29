import { cx } from "@/lib/cx";
import { seededRandom, squaresPath, type Cell } from "@/lib/pixels";

/**
 * A jagged band of pixels where one section gives way to the next, like
 * terrain seen from the side. Pixels use the text color and rise from the
 * bottom; `flip` hangs them from the top instead. The pattern is seeded, so
 * it renders the same on every visit.
 */
export function PixelEdge({
  seed,
  columns = 72,
  rows = 8,
  flip = false,
  className,
}: {
  seed: number;
  columns?: number;
  rows?: number;
  flip?: boolean;
  className?: string;
}) {
  const { pixels, accents } = terrain(seed, columns, rows);

  return (
    <svg
      viewBox={`0 0 ${columns} ${rows}`}
      shapeRendering="crispEdges"
      aria-hidden
      className={cx("block h-auto w-full fill-current", flip && "-scale-y-100", className)}
    >
      <path d={squaresPath(pixels)} />
      <path d={squaresPath(accents)} className="fill-blue" />
    </svg>
  );
}

/** How likely a cell is to be filled, by how far it sits below the ground line. */
function fillChance(depth: number) {
  if (depth >= 1) return 1;
  if (depth === 0) return 0.85;
  if (depth === -1) return 0.3;
  if (depth === -2) return 0.12;
  return 0.03;
}

function terrain(seed: number, columns: number, rows: number) {
  const random = seededRandom(seed);
  const pixels: Cell[] = [];
  const accents: Cell[] = [];

  // The ground wanders up and down a little from one column to the next.
  let groundHeight = rows / 2;
  for (let x = 0; x < columns; x++) {
    groundHeight = Math.min(rows - 2, Math.max(2, groundHeight + (random() - 0.5) * 2.4));
    const groundTop = rows - Math.round(groundHeight);

    for (let y = 0; y < rows; y++) {
      const depth = y - groundTop;
      if (random() >= fillChance(depth)) continue;
      // A few blue pixels along the surface.
      if (depth <= 0 && random() < 0.1) accents.push({ x, y });
      else pixels.push({ x, y });
    }
  }

  return { pixels, accents };
}
