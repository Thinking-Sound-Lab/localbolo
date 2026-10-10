/** Product Hunt's "Featured" badge, linking to the LocalBolo page there. */
export function ProductHuntBadge({ className }: { className?: string }) {
  return (
    <a
      href="https://www.producthunt.com/products/localbolo?embed=true&utm_source=badge-featured&utm_medium=badge&utm_campaign=badge-localbolo"
      target="_blank"
      rel="noopener noreferrer"
      className={className}
    >
      {/* Product Hunt serves the badge as an SVG with live counts, so next/image has nothing to optimize. */}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        alt="LocalBolo - Dictation using Open Source Models only. | Product Hunt"
        width={250}
        height={54}
        className="block"
        src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=1267513&theme=light&t=1791628597662"
      />
    </a>
  );
}
