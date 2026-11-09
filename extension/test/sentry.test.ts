import { describe, expect, it } from "vitest";
import { sentryIntegrations, startSentry } from "../src/shared/sentry";

describe("sentry", () => {
  it("leaves out every integration that touches global state", () => {
    const names = sentryIntegrations().map((integration) => integration.name);
    for (const global of ["Breadcrumbs", "GlobalHandlers", "BrowserApiErrors", "HttpContext", "BrowserSession"]) {
      expect(names).not.toContain(global);
    }
    expect(names).toContain("Dedupe");
  });

  it("does nothing without a DSN", () => {
    expect(() => startSentry("")(new Error("ignored"))).not.toThrow();
  });
});
