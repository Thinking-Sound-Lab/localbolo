import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async headers() {
    return ["/appsumo/:path*", "/api/licenses/:path*", "/api/webhooks/appsumo", "/appsumo"].map((source) => ({
      source,
      headers: [
        { key: "Cache-Control", value: "private, no-store" },
        { key: "Referrer-Policy", value: source === "/appsumo" ? "same-origin" : "no-referrer" },
        { key: "X-Robots-Tag", value: "noindex, nofollow" },
        { key: "X-Frame-Options", value: "DENY" },
        { key: "Content-Security-Policy", value: "frame-ancestors 'none'; form-action 'self'" },
      ],
    }));
  },
};

export default nextConfig;
