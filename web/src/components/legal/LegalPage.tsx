import Link from "next/link";
import type { ReactNode } from "react";
import { SiteHeader } from "@/components/SiteHeader";

/** Where a learner writes about privacy or the terms. Change it here; both pages read it. */
export const CONTACT_EMAIL = "privacy@saynata.com";

/** The date at the top of both pages. Change it with every change to their text. */
export const LEGAL_UPDATED = "4 November 2026";

/** /privacy and /terms (TASK-102.4, doc-23): one reading column with the header, a title and plain sections. */
export function LegalPage({ title, intro, children }: { title: string; intro: string; children: ReactNode }) {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto w-full max-w-[680px] flex-1 px-4 pt-8 pb-16 sm:px-6">
        <h1 className="font-display text-3xl">{title}</h1>
        <p className="mt-2 text-sm text-muted">Last updated {LEGAL_UPDATED}</p>
        <p className="mt-4 text-ink-2">{intro}</p>
        <div className="mt-6 flex flex-col gap-8">{children}</div>
      </main>
      <LegalFooter />
    </>
  );
}

/** One titled part of a legal page. */
export function LegalSection({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="flex flex-col gap-3 text-[0.95rem] leading-relaxed text-ink-2">
      <h2 className="text-lg font-semibold text-ink">{title}</h2>
      {children}
    </section>
  );
}

/** The two links under the homepage and the legal pages. */
export function LegalFooter({ note }: { note?: string }) {
  return (
    <footer className="mx-auto w-full max-w-[1224px] px-4 pb-8 text-center text-xs text-muted sm:px-6">
      {note && <p>{note}</p>}
      <nav aria-label="Legal" className={note ? "mt-2" : undefined}>
        <Link href="/privacy" className="hover:underline">
          Privacy
        </Link>
        <span aria-hidden="true"> · </span>
        <Link href="/terms" className="hover:underline">
          Terms
        </Link>
      </nav>
    </footer>
  );
}
