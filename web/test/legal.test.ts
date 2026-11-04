import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

// The header reads the session and the router; these pages only need it to exist.
vi.mock("@/components/SiteHeader", () => ({ SiteHeader: () => null }));

const { default: PrivacyPage, metadata: privacyMeta } = await import("../src/app/privacy/page");
const { default: TermsPage, metadata: termsMeta } = await import("../src/app/terms/page");
const { LegalFooter } = await import("../src/components/legal/LegalPage");

const render = (page: () => React.ReactElement) => renderToStaticMarkup(createElement(page));

describe("/privacy", () => {
  const html = render(PrivacyPage);

  it("renders the policy with its title", () => {
    expect(html).toContain("<h1");
    expect(html).toContain("Privacy policy");
    expect(privacyMeta.title).toBe("Privacy policy · Saynata");
  });

  it("names every service that gets data", () => {
    for (const name of ["Our server", "DeepSeek", "Gemini", "PostHog", "Sentry", "Resend"]) expect(html).toContain(name);
  });

  it("says usage events never carry the looked-up text", () => {
    expect(html).toContain("never carries what you looked up, typed, selected or copied");
  });

  it("says what we keep, how long, and how to delete the account", () => {
    expect(html).toContain("What we keep and why");
    expect(html).toContain("How long we keep it");
    expect(html).toContain("Delete your account");
    expect(html).toContain('href="/account"');
  });
});

describe("/terms", () => {
  const html = render(TermsPage);

  it("renders the terms with its title and a link to the policy", () => {
    expect(html).toContain("Terms of use");
    expect(html).toContain('href="/privacy"');
    expect(termsMeta.title).toBe("Terms of use · Saynata");
  });
});

describe("footer", () => {
  it("links both pages", () => {
    const html = renderToStaticMarkup(createElement(LegalFooter, { note: "Simple English first." }));
    expect(html).toContain('href="/privacy"');
    expect(html).toContain('href="/terms"');
    expect(html).toContain("Simple English first.");
  });
});
