import { cx } from "@/lib/cx";
import { dotsPath, seededRandom, squaresPath, type Cell } from "@/lib/pixels";

/**
 * Pixels piling up from both bottom corners: squares on the left (text),
 * dots on the right (voice). Meant for a dark background. Seeded, so it
 * renders the same on every visit.
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
  const shades = { blue: [] as Cell[], soft: [] as Cell[], white: [] as Cell[] };
  const dots = { blue: [] as Cell[], soft: [] as Cell[], white: [] as Cell[] };

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
      (isLeft ? shades : dots)[shade].push({ x, y });
    }
  }

  return (
    <svg
      viewBox={`0 0 ${columns} ${rows}`}
      shapeRendering="crispEdges"
      aria-hidden
      className={cx("block h-auto w-full", className)}
    >
      <path d={squaresPath(shades.soft)} className="fill-blue-soft" />
      <path d={squaresPath(shades.blue)} className="fill-blue" />
      <path d={squaresPath(shades.white)} className="fill-white" />
      <g shapeRendering="geometricPrecision">
        <path d={dotsPath(dots.soft)} className="fill-blue-soft" />
        <path d={dotsPath(dots.blue)} className="fill-blue" />
        <path d={dotsPath(dots.white)} className="fill-white" />
      </g>
    </svg>
  );
}
