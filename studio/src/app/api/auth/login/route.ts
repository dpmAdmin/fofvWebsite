import { NextResponse } from "next/server";

import {
  SESSION_COOKIE,
  createSessionToken,
  sessionCookieOptions,
  verifyPassword,
} from "@/lib/auth";

/** Small fixed delay so failed attempts cannot be hammered at full speed. */
const FAILURE_DELAY_MS = 500;

export async function POST(request: Request) {
  let password: unknown;
  try {
    ({ password } = await request.json());
  } catch {
    return NextResponse.json({ error: "Expected a JSON body." }, { status: 400 });
  }

  if (typeof password !== "string" || password.length === 0) {
    return NextResponse.json({ error: "Enter your studio password." }, { status: 400 });
  }

  let ok: boolean;
  try {
    ok = verifyPassword(password);
  } catch (error) {
    // Misconfigured server (no STUDIO_PASSWORD set) — say so plainly instead of
    // pretending the password was wrong.
    console.error("Studio login is not configured:", error);
    return NextResponse.json(
      { error: "This studio is not configured yet. Set STUDIO_PASSWORD on the server." },
      { status: 500 },
    );
  }

  if (!ok) {
    await new Promise((resolve) => setTimeout(resolve, FAILURE_DELAY_MS));
    return NextResponse.json({ error: "That password is not right." }, { status: 401 });
  }

  const response = NextResponse.json({ ok: true });
  response.cookies.set(SESSION_COOKIE, await createSessionToken(), sessionCookieOptions);
  return response;
}
