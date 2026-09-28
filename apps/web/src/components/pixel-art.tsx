import { cx } from "@/lib/cx";
import { parsePixelArt, squaresPath, type PixelArtRows } from "@/lib/pixels";

/**
 * Renders pixel art (see `PixelArtRows`) as a crisp SVG. Pixels use the text
 * color; accent pixels are blue unless `accentClassName` says otherwise.
 */
export function PixelArt({
  art,
  className,
  accentClassName = "fill-blue",
  label,
}: {
  art: PixelArtRows;
  className?: string;
  accentClassName?: string;
  /** Describes the image for screen readers. Decorative art can leave this out. */
  label?: string;
}) {
  const { width, height, pixels, accents } = parsePixelArt(art);

  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      shapeRendering="crispEdges"
      className={cx("fill-current", className)}
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
    >
      <path d={squaresPath(pixels)} />
      {accents.length > 0 ? <path d={squaresPath(accents)} className={accentClassName} /> : null}
    </svg>
  );
}
