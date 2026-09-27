import { ImageResponse } from "next/og";
import { site } from "@/lib/site";

export const alt = `${site.name}: ${site.tagline}`;
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

const barHeights = [24, 44, 64, 80, 56, 80, 64, 44, 24];

export default function OpenGraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          gap: 56,
          background: "#f7f5f0",
          color: "#0e0e10",
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 12,
            padding: "36px 64px",
            borderRadius: 999,
            background: "#0e0e10",
            boxShadow: "0 30px 60px -20px rgba(0,0,0,0.45)",
          }}
        >
          {barHeights.map((height, index) => (
            <div key={index} style={{ width: 14, height, borderRadius: 7, background: "#ffffff" }} />
          ))}
        </div>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 12 }}>
          <div style={{ fontSize: 76, fontWeight: 700, letterSpacing: -2 }}>{site.name}</div>
          <div style={{ fontSize: 36, color: "#57544e" }}>
            Hold fn, speak, and let go. Private dictation for Mac.
          </div>
        </div>
      </div>
    ),
    size,
  );
}
