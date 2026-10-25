import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { DownloadCards } from "../src/components/download/DownloadCards";
import { DOWNLOADS, detectDevice, liveUrl, orderPlatforms, type Platform, type PlatformConfig } from "../src/lib/downloads";

const IPHONE = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 Version/18.5 Mobile/15E148 Safari/604.1";
const MAC = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/18.5 Safari/605.1.15";
const WINDOWS_EDGE = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0 Safari/537.36 Edg/130.0";
const ANDROID = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130.0 Mobile Safari/537.36";

const soon: Record<Platform, PlatformConfig> = {
  iphone: { status: "soon", requirement: "iOS 18 or later" },
  mac: { status: "soon", url: "https://example.com/ignored", requirement: "macOS 15 or later" },
  extension: { status: "soon", requirement: "Chrome and Edge" },
};

describe("device detection and order", () => {
  it("finds the visitor's device", () => {
    expect(detectDevice(IPHONE)).toBe("iphone");
    expect(detectDevice(MAC)).toBe("mac");
    expect(detectDevice(WINDOWS_EDGE)).toBe("chromium");
    expect(detectDevice(ANDROID)).toBe("other");
    expect(detectDevice(null)).toBe("other");
  });

  it("puts the visitor's platform first", () => {
    expect(orderPlatforms("iphone")).toEqual(["iphone", "mac", "extension"]);
    expect(orderPlatforms("mac")).toEqual(["mac", "iphone", "extension"]);
    expect(orderPlatforms("chromium")).toEqual(["extension", "iphone", "mac"]);
    expect(orderPlatforms("other")).toEqual(["iphone", "mac", "extension"]);
  });
});

describe("download config", () => {
  it("starts with every platform coming soon", () => {
    for (const config of Object.values(DOWNLOADS)) expect(liveUrl(config)).toBeNull();
  });

  it("gives a link only when live and a url is set", () => {
    expect(liveUrl({ status: "live", url: "https://x.test", requirement: "" })).toBe("https://x.test");
    expect(liveUrl({ status: "live", requirement: "" })).toBeNull();
    expect(liveUrl({ status: "soon", url: "https://x.test", requirement: "" })).toBeNull();
  });
});

describe("DownloadCards", () => {
  it("renders no link for a coming soon platform", () => {
    const html = renderToStaticMarkup(createElement(DownloadCards, { device: "other", config: soon }));
    expect(html).not.toContain("<a ");
    expect(html.match(/Coming soon/g)).toHaveLength(3);
  });

  it("renders the store url in a new tab for a live platform", () => {
    const config = {
      ...soon,
      iphone: { status: "live" as const, url: "https://apps.apple.com/app/x", requirement: "iOS 18 or later" },
    };
    const html = renderToStaticMarkup(createElement(DownloadCards, { device: "iphone", config }));
    expect(html).toContain('href="https://apps.apple.com/app/x"');
    expect(html).toContain('target="_blank"');
    expect(html).toContain('rel="noopener noreferrer"');
    expect(html.match(/Coming soon/g)).toHaveLength(2);
  });

  it("shows the QR code only to a non-iPhone visitor when iOS is live", () => {
    const config = { ...soon, iphone: { status: "live" as const, url: "https://apps.apple.com/app/x", requirement: "" } };
    const qrSvg = "<svg></svg>";
    expect(renderToStaticMarkup(createElement(DownloadCards, { device: "mac", config, qrSvg }))).toContain("QR code");
    expect(renderToStaticMarkup(createElement(DownloadCards, { device: "iphone", config, qrSvg }))).not.toContain("QR code");
  });
});
