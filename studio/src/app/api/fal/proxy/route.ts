import { createRouteHandler } from "@fal-ai/server-proxy/nextjs";

import { SESSION_COOKIE, verifySessionToken } from "@/lib/auth";
import { MODELS } from "@/lib/models";

/**
 * Server-side proxy to the fal.ai API.
 *
 * The browser never sees FAL_KEY: the client posts to this route, and the
 * proxy attaches credentials from the server environment before forwarding to
 * fal. `src/proxy.ts` already blocks unauthenticated traffic, but this handler
 * checks the session again so the credit-spending path stays closed even if
 * that matcher is ever loosened.
 */

/**
 * Restrict the proxy to the endpoints the studio actually offers.
 *
 * Without this, an authenticated user could drive *any* fal model through the
 * key — including far more expensive ones than the catalogue exposes. Adding a
 * model to `MODELS` allows it here automatically.
 *
 * Each endpoint contributes two patterns: the endpoint itself (queue submits
 * POST to `queue.fal.run/<endpoint>`) and everything beneath it (cancelling a
 * job POSTs to `queue.fal.run/<endpoint>/requests/<id>/cancel`, which an
 * exact-match-only list would reject).
 *
 * Storage uploads are unaffected — they target `rest.fal.ai`, and the proxy
 * skips this check for `*.fal.ai` hosts.
 */
const allowedEndpoints = [...new Set(MODELS.map((model) => model.endpointId))].flatMap(
  (endpointId) => [endpointId, `${endpointId}/**`],
);

export const { GET, POST, PUT } = createRouteHandler({
  allowUnauthorizedRequests: false,
  allowedEndpoints,

  isAuthenticated: async (behavior) => {
    const cookieHeader = behavior.getHeader("cookie");
    const raw = Array.isArray(cookieHeader) ? cookieHeader.join("; ") : cookieHeader;
    if (!raw) return false;

    const token = raw
      .split(";")
      .map((part) => part.trim())
      .find((part) => part.startsWith(`${SESSION_COOKIE}=`))
      ?.slice(SESSION_COOKIE.length + 1);

    return verifySessionToken(token && decodeURIComponent(token));
  },
});

// The proxy streams queue updates, so it must not be statically evaluated.
export const dynamic = "force-dynamic";
