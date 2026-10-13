import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Genera .next/standalone con un server.js mínimo y solo las dependencias
  // necesarias, ideal para imágenes Docker pequeñas.
  output: "standalone",
  cacheComponents: true,
  partialPrefetching: true,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
