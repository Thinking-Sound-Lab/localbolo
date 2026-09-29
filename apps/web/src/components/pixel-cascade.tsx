import { cx } from "@/lib/cx";
import { seededRandom, squaresPath, type Cell } from "@/lib/pixels";

/** Gap left around each pixel on the right-hand side, in cells. */
const spacedInset = 0.14;

/**
 * Square pixels piling up from both bottom corners: solid blocks on the left,
 * spaced-out pixels like a display matrix on the right. Meant for a dark
 * background. Seeded, so it renders the same on every visit.
 */
export function PixelCascade({
  seed,
  columns = 64,
  rows = 18,
  className,
}: {
  seed: number;
  columns?: number;
  rows?: number;
  className?: string;
}) {
  const random = seededRandom(seed);
  const solid = { blue: [] as Cell[], soft: [] as Cell[], white: [] as Cell[] };
  const spaced = { blue: [] as Cell[], soft: [] as Cell[], white: [] as Cell[] };

  for (let x = 0; x < columns; x++) {
    const isLeft = x < columns / 2;
    // 0 at the nearest side edge, 1 at the centre.
    const fromSide = (isLeft ? x : columns - 1 - x) / (columns / 2);

    for (let y = 0; y < rows; y++) {
      const fromBottom = (rows - 1 - y) / rows;
      // Filled near the corner, thinning out towards the middle and the top.
      const chance = 1.35 - fromSide * 1.6 - fromBottom * 1.25;
      if (random() >= chance) continue;

      const pick = random();
      const shade = pick < 0.55 ? "soft" : pick < 0.85 ? "blue" : "white";
      (isLeft ? solid : spaced)[shade].push({ x, y });
    }
  }

  return (
    <svg
      viewBox={`0 0 ${columns} ${rows}`}
      shapeRendering="crispEdges"
      aria-hidden
      className={cx("block h-auto w-full", className)}
    >
      <path d={squaresPath(solid.soft)} className="fill-blue-soft" />
      <path d={squaresPath(solid.blue)} className="fill-blue" />
      <path d={squaresPath(solid.white)} className="fill-white" />
      <path d={squaresPath(spaced.soft, spacedInset)} className="fill-blue-soft" />
      <path d={squaresPath(spaced.blue, spacedInset)} className="fill-blue" />
      <path d={squaresPath(spaced.white, spacedInset)} className="fill-white" />
    </svg>
  );
}
