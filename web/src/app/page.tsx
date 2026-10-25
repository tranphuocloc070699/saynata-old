import { Suspense } from "react";
import { Home } from "@/components/home/Home";
import { SiteHeader } from "@/components/SiteHeader";

/**
 * The homepage (TASK-102.1, direction B): one reading column, the composer on top, the result below.
 * The header and the intro are static HTML; the tool reads ?q= on the client, inside Suspense.
 */
export default function Page() {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto flex w-full max-w-[1224px] flex-1 flex-col gap-6 px-4 pb-16 sm:px-6">
        <Suspense fallback={<div className="min-h-[170px]" />}>
          <Home />
        </Suspense>
      </main>
      <footer className="mx-auto w-full max-w-[1224px] px-4 pb-8 text-center text-xs text-muted sm:px-6">
        Simple English first. Your language last.
      </footer>
    </>
  );
}
