"use client";
/**
 * The pixel-art cat room on the left of the sign-in page (doc-23). The developer's CatRoom code: one of two rooms,
 * 50/50 per mount, with furniture cut from one sheet and a Pochi cat that sleeps (cozy) or runs (playful), all CSS
 * (globals.css .cat-room). The pictures are the paid CatMegaBundle, never in git: Caddy serves them at /cats/
 * (scripts/upload-web-cats.sh). Without them a plain panel with our own PixelCat shows. Hidden under 760px.
 */
import { useEffect, useRef, useState, type CSSProperties } from "react";
import { CAT_BASE_URL, loadImage } from "@/lib/mochi";
import { PixelCat } from "./PixelCat";

export type RoomKind = "cozy" | "playful";

// [cx, cy, w, h, x, y, scale]: the item's box in the 1024px furniture sheet, then where it sits in the 512px room.
type Item = readonly [number, number, number, number, number, number, number];

const COMMON: Item[] = [
  [675, 301, 95, 145, 65, 126, 0.85],
  [15, 0, 66, 97, 365, 144, 0.8],
];

const FURNITURE: Record<RoomKind, Item[]> = {
  cozy: [
    ...COMMON,
    [10, 288, 104, 130, 56, 223, 0.85],
    [137, 299, 50, 110, 183, 202, 0.85],
    [192, 230, 124, 88, 266, 280, 1],
    [284, 0, 71, 129, 374, 239, 0.65],
    [263, 615, 52, 48, 185, 365, 0.65],
    [263, 432, 51, 46, 231, 384, 0.65],
  ],
  playful: [
    ...COMMON,
    [136, 422, 52, 110, 204, 206, 0.8],
    [192, 134, 124, 88, 83, 281, 0.9],
    [553, 222, 121, 163, 305, 176, 1],
    [263, 615, 52, 48, 209, 393, 0.65],
    [263, 432, 51, 46, 251, 381, 0.65],
  ],
};

type Shown = { kind: "pending" } | { kind: "room"; room: RoomKind } | { kind: "fallback" };

export function CatRoom({ className = "" }: { className?: string }) {
  // "pending" on the server and the first client render so the HTML matches; the room is picked in the browser.
  const [shown, setShown] = useState<Shown>({ kind: "pending" });
  const [paused, setPaused] = useState(true);
  const figure = useRef<HTMLElement>(null);

  useEffect(() => {
    const room: RoomKind = Math.random() < 0.5 ? "cozy" : "playful";
    let live = true;
    void loadImage(`${CAT_BASE_URL}${room}.png`).then((ok) => {
      if (live) setShown(ok ? { kind: "room", room } : { kind: "fallback" });
    });
    return () => {
      live = false;
    };
  }, []);

  // The cat moves only while the room is on screen and the tab is visible.
  useEffect(() => {
    const node = figure.current;
    if (!node) return;
    let onscreen = false;
    const sync = () => setPaused(document.hidden || !onscreen);
    const observer = new IntersectionObserver(
      ([entry]) => {
        onscreen = entry.isIntersecting;
        sync();
      },
      { threshold: 0 },
    );
    observer.observe(node);
    document.addEventListener("visibilitychange", sync);
    return () => {
      observer.disconnect();
      document.removeEventListener("visibilitychange", sync);
    };
  }, [shown.kind]);

  if (shown.kind !== "room") {
    return (
      <figure
        ref={figure}
        className={`cat-room cat-room--fallback ${className}`}
        aria-hidden={shown.kind === "pending" ? true : undefined}
      >
        <div className="cat-room__scene flex items-center justify-center">
          {shown.kind === "fallback" && <PixelCat mood="asleep" className="w-1/3" />}
        </div>
        {shown.kind === "fallback" && (
          <figcaption className="cat-room__description">A quiet corner for a little nap.</figcaption>
        )}
      </figure>
    );
  }

  const { room } = shown;
  const playful = room === "playful";
  const frames = playful ? 6 : 4;
  const sprite = {
    "--frames": frames,
    "--sprite-duration": playful ? "0.75s" : "1.333s",
    width: `${frames * 100}%`,
  } as CSSProperties;

  return (
    <figure ref={figure} className={`cat-room cat-room--${room} ${paused ? "cat-room--paused" : ""} ${className}`}>
      <div className="cat-room__scene" aria-hidden="true">
        <svg className="cat-room__art" viewBox="0 0 512 512" focusable="false">
          <image href={`${CAT_BASE_URL}${room}.png`} width="512" height="512" />
          {FURNITURE[room].map(([cx, cy, w, h, x, y, scale]) => (
            <svg
              key={`${cx}-${cy}-${x}-${y}`}
              x={x}
              y={y}
              width={w * scale}
              height={h * scale}
              viewBox={`${cx} ${cy} ${w} ${h}`}
              overflow="hidden"
            >
              <image href={`${CAT_BASE_URL}furniture.png`} width="1024" height="1024" />
            </svg>
          ))}
        </svg>
        <div className="cat-room__cat-position">
          <div className="cat-room__cat-facing">
            <div className="cat-room__sprite-window">
              {/* eslint-disable-next-line @next/next/no-img-element -- a sprite strip moved by CSS, not a photo */}
              <img
                className="cat-room__sprite-strip"
                src={`${CAT_BASE_URL}${playful ? "running" : "sleeping"}.png`}
                alt=""
                draggable={false}
                style={sprite}
              />
            </div>
          </div>
        </div>
      </div>
      <figcaption className="cat-room__description">
        {playful ? "A little run around the room." : "A quiet corner for a little nap."}
      </figcaption>
    </figure>
  );
}
