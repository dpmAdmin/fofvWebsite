import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Generated assets are served straight from fal's CDN. We render them with
  // plain <img>/<video> tags rather than next/image so that new fal storage
  // hosts never require a config change to display correctly.
  reactStrictMode: true,
};

export default nextConfig;
