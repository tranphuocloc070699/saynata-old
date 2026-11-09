import type { NextConfig } from "next";
import { withSentryConfig } from "@sentry/nextjs/config";

/**
 * The backend the /api rewrite points at. In production Caddy sends /api to the backend on the same domain,
 * so this rewrite is only for `next dev` and `next start` (doc-23). The backend has no CORS setup.
 */
const apiOrigin = process.env.SAYNATA_API_ORIGIN ?? "https://api.saynata.com";

const nextConfig: NextConfig = {
  // A small self-contained server (.next/standalone) that runs in the web container (doc-23, Deploy).
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
  async rewrites() {
    return [{ source: "/api/:path*", destination: `${apiOrigin}/api/:path*` }];
  },
};

// Sentry (TASK-128.4): source maps are uploaded only when SENTRY_AUTH_TOKEN is set (the deploy job), so stack traces
// from real users stay readable. Without it the build works as before.
export default withSentryConfig(nextConfig, {
  org: "tran-phuoc-loc",
  project: "saynata-web",
  authToken: process.env.SENTRY_AUTH_TOKEN,
  widenClientFileUpload: true,
  silent: !process.env.CI,
});
