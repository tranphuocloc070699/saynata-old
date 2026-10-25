/**
 * The three Download cards (TASK-102.9, doc-23, layout A: stacked). A server component with no state, so a test can
 * render it. A "soon" platform shows a pill and no link; a "live" one shows the store button (opens in a new tab).
 */
import type { ReactNode } from "react";
import { DOWNLOADS, liveUrl, orderPlatforms, type Device, type Platform, type PlatformConfig } from "@/lib/downloads";
import { Laptop, Phone, Puzzle } from "../icons";

const COPY: Record<Platform, { name: string; line: string; button: string; icon: ReactNode }> = {
  iphone: {
    name: "iPhone",
    line: "Share any text from Safari, hear it, and practise saying it.",
    button: "Download on the App Store",
    icon: <Phone />,
  },
  mac: {
    name: "Mac",
    line: "Press ⌥⇧Space anywhere to explain what you selected.",
    button: "Download on the Mac App Store",
    icon: <Laptop />,
  },
  extension: {
    name: "Browser extension",
    line: "Select English on any page and see the simple meaning.",
    button: "Add to Chrome",
    icon: <Puzzle />,
  },
};

type Props = {
  device: Device;
  /** The App Store QR code as an SVG string. Shown on the iPhone card only for a visitor who is not on an iPhone. */
  qrSvg?: string | null;
  /** Override the config (tests). */
  config?: Record<Platform, PlatformConfig>;
};

export function DownloadCards({ device, qrSvg, config = DOWNLOADS }: Props) {
  return (
    <ul className="mt-8 flex flex-col gap-3">
      {orderPlatforms(device).map((platform) => (
        <li key={platform}>
          <Card
            platform={platform}
            config={config[platform]}
            qrSvg={platform === "iphone" && device !== "iphone" ? qrSvg : null}
          />
        </li>
      ))}
    </ul>
  );
}

function Card({ platform, config, qrSvg }: { platform: Platform; config: PlatformConfig; qrSvg?: string | null }) {
  const copy = COPY[platform];
  const url = liveUrl(config);
  return (
    <section
      aria-label={copy.name}
      data-platform={platform}
      className="flex flex-wrap items-center gap-4 rounded-2xl border border-hairline bg-surface p-4 sm:p-5"
    >
      <div className="grid size-14 shrink-0 place-items-center rounded-2xl bg-meaning text-accent">
        <span className="size-7">{copy.icon}</span>
      </div>
      <div className="min-w-0 flex-1 basis-48">
        <h2 className="text-base font-semibold">{copy.name}</h2>
        <p className="mt-0.5 text-sm text-ink-2">{copy.line}</p>
        <p className="mt-1 text-xs text-muted">{config.requirement}</p>
      </div>
      {url ? (
        <div className="flex items-center gap-4">
          {qrSvg && (
            <div
              role="img"
              aria-label="QR code for the App Store"
              className="hidden size-24 shrink-0 rounded-xl bg-white p-1.5 sm:block [&>svg]:size-full"
              dangerouslySetInnerHTML={{ __html: qrSvg }}
            />
          )}
          <a
            href={url}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex min-h-11 items-center rounded-full bg-accent px-5 text-sm font-semibold text-on-accent"
          >
            {copy.button}
          </a>
        </div>
      ) : (
        <span className="inline-flex min-h-8 items-center rounded-full bg-chip px-3 text-xs font-semibold text-accent">
          Coming soon
        </span>
      )}
    </section>
  );
}
