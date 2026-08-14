import { NextResponse, type NextRequest } from "next/server";

import { SESSION_COOKIE, verifySessionToken } from "@/lib/auth";

/**
 * Gates the whole studio — including the fal proxy — behind a valid session.
 *
 * The fal proxy route re-checks the session itself; this is the outer layer so
 * an unauthenticated request never reaches route code at all.
 *
 * (This is Next 16's `proxy` convention, the replacement for `middleware`.)
 */
export default async function proxy(request: NextRequest) {
  const isAuthed = await verifySessionToken(request.cookies.get(SESSION_COOKIE)?.value);
  if (isAuthed) return NextResponse.next();

  // API calls get a JSON 401 — a redirect here would reach the fal client as an
  // unparseable HTML body and surface as a confusing error.
  if (request.nextUrl.pathname.startsWith("/api/")) {
    return NextResponse.json({ error: "Not authenticated." }, { status: 401 });
  }

  const loginUrl = new URL("/login", request.url);
  const returnTo = request.nextUrl.pathname + request.nextUrl.search;
  if (returnTo && returnTo !== "/") loginUrl.searchParams.set("next", returnTo);
  return NextResponse.redirect(loginUrl);
}

export const config = {
  matcher: [
    /*
     * Everything except the login page, the auth endpoints that issue the
     * session, Next's build output, and public static files.
     *
     * `icon.svg` is listed so the brand mark still renders on the login page,
     * which is shown to visitors who have no session yet.
     */
    "/((?!login|api/auth/|_next/static|_next/image|favicon.ico|icon.svg|robots.txt).*)",
  ],
};
