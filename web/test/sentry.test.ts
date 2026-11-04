import { describe, expect, it } from "vitest";
import type { Breadcrumb, ErrorEvent } from "@sentry/nextjs";
import { scrubBreadcrumb, scrubEvent, scrubSpan, scrubUrl, type SpanJSON } from "../src/lib/sentry";

describe("scrubUrl", () => {
  it("drops the query string, so ?q= text never leaves", () => {
    expect(scrubUrl("https://saynata.com/?q=give%20up#top")).toBe("https://saynata.com/#top");
  });

  it("replaces the looked-up word in GET /api/words/{word}", () => {
    expect(scrubUrl("GET /api/words/serendipity")).toBe("GET /api/words/:word");
    expect(scrubUrl("https://saynata.com/api/words/give-up?x=1")).toBe("https://saynata.com/api/words/:word");
  });

  it("keeps /api/words/hot and other paths", () => {
    expect(scrubUrl("/api/words/hot?limit=10")).toBe("/api/words/hot");
    expect(scrubUrl("/api/me/settings")).toBe("/api/me/settings");
  });
});

describe("scrub hooks", () => {
  it("cleans the request of an error event", () => {
    const event = { request: { url: "https://saynata.com/?q=hello", query_string: "q=hello" } } as ErrorEvent;
    expect(scrubEvent(event).request).toEqual({ url: "https://saynata.com/" });
  });

  it("cleans navigation and fetch breadcrumbs", () => {
    const nav = scrubBreadcrumb({ category: "navigation", data: { from: "/", to: "/?q=hello" } } as Breadcrumb);
    expect(nav.data).toEqual({ from: "/", to: "/" });
    const fetch = scrubBreadcrumb({ category: "fetch", data: { url: "/api/words/hello" } } as Breadcrumb);
    expect(fetch.data?.url).toBe("/api/words/:word");
  });

  it("cleans span names and URL attributes", () => {
    const span = scrubSpan({ name: "GET /api/words/hello", attributes: { "url.full": "/?q=hi" } } as unknown as SpanJSON);
    expect(span.name).toBe("GET /api/words/:word");
    expect(span.attributes["url.full"]).toBe("/");
  });
});
