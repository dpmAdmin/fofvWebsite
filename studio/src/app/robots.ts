import type { MetadataRoute } from "next";

/** The studio is an internal tool — keep it out of search results entirely. */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: "*", disallow: "/" },
  };
}
