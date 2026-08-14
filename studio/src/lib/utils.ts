/** Joins class names, dropping falsy values. */
export function cn(...classes: (string | false | null | undefined)[]): string {
  return classes.filter(Boolean).join(" ");
}

/** "3 minutes ago", "2 days ago", … */
export function timeAgo(timestamp: number): string {
  const seconds = Math.round((Date.now() - timestamp) / 1000);
  if (seconds < 60) return "just now";

  const units: [label: string, seconds: number][] = [
    ["day", 86400],
    ["hour", 3600],
    ["minute", 60],
  ];

  for (const [label, size] of units) {
    const value = Math.floor(seconds / size);
    if (value >= 1) return `${value} ${label}${value === 1 ? "" : "s"} ago`;
  }
  return "just now";
}

/** Formats elapsed milliseconds as `M:SS` or `SSs`. */
export function formatElapsed(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000);
  if (totalSeconds < 60) return `${totalSeconds}s`;
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${String(seconds).padStart(2, "0")}`;
}

/**
 * Downloads a remote asset.
 *
 * fal's CDN is cross-origin, so a plain `<a download>` would navigate to the
 * file instead of saving it. Fetching to a blob first keeps it a real download
 * and lets us control the filename. Falls back to opening the URL if the fetch
 * is blocked.
 */
export async function downloadUrl(url: string, filename: string): Promise<void> {
  try {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);

    const blob = await response.blob();
    const objectUrl = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = objectUrl;
    anchor.download = filename;
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    URL.revokeObjectURL(objectUrl);
  } catch {
    window.open(url, "_blank", "noopener,noreferrer");
  }
}
