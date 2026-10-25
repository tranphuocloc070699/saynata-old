import type { Metadata } from "next";
import { SiteHeader } from "@/components/SiteHeader";
import { HistoryView } from "@/components/history/HistoryView";

export const metadata: Metadata = { title: "History · Saynata" };

/** /history (TASK-102.6, doc-23): History and Liked, the same lists as on the phone and the Mac. */
export default function Page() {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto flex w-full max-w-[680px] flex-1 flex-col gap-4 px-4 pb-16 sm:px-6">
        <HistoryView />
      </main>
    </>
  );
}
