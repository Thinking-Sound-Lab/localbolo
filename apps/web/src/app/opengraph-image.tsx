import { ImageResponse } from "next/og";
import { site } from "@/lib/site";

export const alt = `${site.name}: ${site.tagline}`;
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

const columns = 46;
const rows = 9;
const middleRow = (rows - 1) / 2;

/** Rows lit on each side of the middle, per column: a still frame of the site's pixel waveform. */
const reach = Array.from({ length: columns }, (_, column) => {
  const position = column / (columns - 1);
  const syllables = 0.5 + 0.5 * Math.sin(position * 34);
  const words = 0.5 + 0.5 * Math.sin(position * 7.5 + 1);
  const loudness = Math.sin(Math.PI * position) ** 0.8 * (0.1 + 0.9 * syllables * (0.35 + 0.65 * words));
  return loudness * (middleRow + 0.5);
});

function pixelColor(column: number, row: number) {
  const distance = Math.abs(row - middleRow);
  if (distance >= reach[column]) return "#262626";
  return distance >= reach[column] - 1 ? "#8e9cff" : "#ffffff";
}

export default function OpenGraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          padding: "64px 72px",
          background: "#0a0a0a",
          color: "#ffffff",
        }}
      >
        <div style={{ display: "flex", justifyContent: "space-between", fontSize: 28 }}>
          <div style={{ display: "flex", fontWeight: 700, letterSpacing: -0.5 }}>{site.name}</div>
          <div style={{ display: "flex", color: "#a3a3a3" }}>
            {site.price.label} once · {site.requirements}
          </div>
        </div>

        <div style={{ display: "flex", flexDirection: "column", fontSize: 88, letterSpacing: -4, lineHeight: 1 }}>
          <div style={{ display: "flex" }}>Talk, and it types.</div>
          <div style={{ display: "flex", color: "#737373" }}>Nothing leaves your Mac.</div>
        </div>

        <div style={{ display: "flex", justifyContent: "space-between" }}>
          {reach.map((_, column) => (
            <div key={column} style={{ display: "flex", flexDirection: "column", gap: 10 }}>
              {Array.from({ length: rows }, (_, row) => (
                <div key={row} style={{ width: 12, height: 12, background: pixelColor(column, row) }} />
              ))}
            </div>
          ))}
        </div>
      </div>
    ),
    size,
  );
}
