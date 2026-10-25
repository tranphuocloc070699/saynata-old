/**
 * The Download page config (TASK-102.9, doc-23). To turn a platform on, change its `status` to "live" and set `url`.
 * That is the only edit needed: the page, the QR code and the card order all read from here.
 */
export type Platform = "iphone" | "mac" | "extension";
export type Status = "soon" | "live";

export type PlatformConfig = {
  status: Status;
  /** Store link. Only used when `status` is "live". */
  url?: string;
  requirement: string;
};

export const DOWNLOADS: Record<Platform, PlatformConfig> = {
  iphone: { status: "soon", requirement: "iOS 18 or later" },
  mac: { status: "soon", requirement: "macOS 15 or later" },
  extension: { status: "soon", requirement: "Chrome and Edge" },
};

/** The link to show, or null when the platform is not live (or has no url yet). */
export function liveUrl(config: PlatformConfig): string | null {
  return config.status === "live" && config.url ? config.url : null;
}

export type Device = "iphone" | "mac" | "chromium" | "other";

/** What kind of visitor this is, from the User-Agent header. A pure function, so it is easy to test. */
export function detectDevice(userAgent: string | null | undefined): Device {
  const ua = userAgent ?? "";
  if (/iPhone|iPod/.test(ua)) return "iphone";
  if (/Android|Mobile|iPad/.test(ua)) return "other";
  if (/Macintosh|Mac OS X/.test(ua)) return "mac";
  if (/Chrome|Chromium|Edg\//.test(ua)) return "chromium";
  return "other";
}

const DEFAULT_ORDER: Platform[] = ["iphone", "mac", "extension"];

/** The cards in the order for this visitor: their own platform first, the rest keep the default order. */
export function orderPlatforms(device: Device): Platform[] {
  const first: Platform | null =
    device === "iphone" ? "iphone" : device === "mac" ? "mac" : device === "chromium" ? "extension" : null;
  if (!first) return DEFAULT_ORDER;
  return [first, ...DEFAULT_ORDER.filter((platform) => platform !== first)];
}
