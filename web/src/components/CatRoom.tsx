"use client";
/**
 * The pixel-art cat room on the left of the sign-in page (doc-23). The developer's RandomCatRoom code: one of two
 * precomposed 512px rooms, 50/50 per mount, with a Pochi cat that sleeps (cozy) or runs (playful), all CSS
 * (globals.css .cat-room). The pictures are the paid CatMegaBundle, never in git: Caddy serves them at /cats/
 * (scripts/upload-web-cats.sh). Without them a plain panel with our own PixelCat shows. Hidden under 760px.
 */
import { useEffect, useRef, useState, type CSSProperties } from "react";
import { CAT_BASE_URL, loadImage } from "@/lib/mochi";
import { PixelCat } from "./PixelCat";

export type RoomKind = "cozy" | "playful";

const ROOMS = {
  cozy: { sprite: "sleeping.png", frames: 4, duration: "1.333333s", description: "A quiet corner for a little nap." },
  playful: { sprite: "running.png", frames: 6, duration: "0.75s", description: "A little run around the room." },
} as const;

type Shown = { kind: "pending" } | { kind: "room"; room: RoomKind } | { kind: "fallback" };

export function CatRoom({ className = "" }: { className?: string }) {
  // "pending" on the server and the first client render so the HTML matches; the room is picked in the browser.
  const [shown, setShown] = useState<Shown>({ kind: "pending" });
  const [paused, setPaused] = useState(true);
  const figure = useRef<HTMLElement>(null);

  useEffect(() => {
    const room: RoomKind = Math.random() < 0.5 ? "cozy" : "playful";
    let live = true;
    // Only the picked room and its sprite strip are fetched; if either is missing the plain panel shows.
    void Promise.all([
      loadImage(`${CAT_BASE_URL}${room}-room.png`),
      loadImage(`${CAT_BASE_URL}${ROOMS[room].sprite}`),
    ]).then(([background, sprite]) => {
      if (live) setShown(background && sprite ? { kind: "room", room } : { kind: "fallback" });
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
  const { sprite, frames, duration, description } = ROOMS[room];
  const strip = { "--frames": frames, "--sprite-duration": duration, width: `${frames * 100}%` } as CSSProperties;

  return (
    <figure ref={figure} className={`cat-room cat-room--${room} ${paused ? "cat-room--paused" : ""} ${className}`}>
      <div className="cat-room__scene" aria-hidden="true">
        {/* eslint-disable-next-line @next/next/no-img-element -- pixel art served from /cats/, not a photo */}
        <img
          className="cat-room__background"
          src={`${CAT_BASE_URL}${room}-room.png`}
          width={512}
          height={512}
          alt=""
          draggable={false}
        />
        <div className="cat-room__route">
          <div className="cat-room__traveler">
            <div className="cat-room__anchor">
              <div className="cat-room__facing">
                <div className="cat-room__sprite-window">
                  {/* eslint-disable-next-line @next/next/no-img-element -- a sprite strip moved by CSS, not a photo */}
                  <img
                    className="cat-room__sprite-strip"
                    src={`${CAT_BASE_URL}${sprite}`}
                    alt=""
                    draggable={false}
                    style={strip}
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <figcaption className="cat-room__description">{description}</figcaption>
    </figure>
  );
}
