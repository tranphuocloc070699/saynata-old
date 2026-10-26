import type { Metadata } from "next";
import { headers } from "next/headers";
import { Suspense } from "react";
import QRCode from "qrcode";
import { SiteHeader } from "@/components/SiteHeader";
import { DownloadCards } from "@/components/download/DownloadCards";
import { DOWNLOADS, detectDevice, liveUrl } from "@/lib/downloads";

export const metadata: Metadata = {
  title: "Download · Saynata",
  description: "Take Saynata with you: iPhone, Mac and the browser extension.",
};

/** /download (TASK-102.9, doc-23): where to get Saynata. The heading is static; the cards wait for the User-Agent. */
export default function Page() {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto w-full max-w-[640px] flex-1 px-4 pt-8 pb-16 sm:px-6">
        <h1 className="font-display text-3xl">Take Saynata everywhere</h1>
        <p className="mt-2 text-sm text-muted">One simple English explanation, on your phone, your Mac and your browser.</p>
        <Suspense fallback={<DownloadCards device="other" />}>
          <CardsForVisitor />
        </Suspense>
      </main>
    </>
  );
}

/** Reads the User-Agent only to put the visitor's platform first. */
async function CardsForVisitor() {
  const device = detectDevice((await headers()).get("user-agent"));
  // The QR code is made on the server (the `qrcode` package), only for a visitor not on an iPhone and only when live.
  const iosUrl = liveUrl(DOWNLOADS.iphone);
  const qrSvg = iosUrl && device !== "iphone" ? await QRCode.toString(iosUrl, { type: "svg", margin: 0 }) : null;
  return <DownloadCards device={device} qrSvg={qrSvg} />;
}
