"use client";
/**
 * The /account page (TASK-102.8, doc-23): profile card, three stat tiles, the 5 most recent History items with a
 * "See all" link, and the delete row. A guest is sent to /sign-in. Delete asks first, calls DELETE /api/me, forgets the session and goes home.
 */
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState, useSyncExternalStore } from "react";
import { ACCOUNT_SIGN_IN_PATH, accountApi, memberLine, statTiles, type Me } from "@/lib/account";
import { ApiError, MESSAGES } from "@/lib/api";
import { browserTokens } from "@/lib/auth";
import { liveItems } from "@/lib/sync";
import { useSync } from "@/lib/useSync";
import { GlassList, HistoryRow, isLiked } from "../history/HistoryRows";
import { IconButton } from "../IconButton";
import { PixelCat } from "../PixelCat";
import { Alert, SignOut, Trash } from "../icons";

const noopSubscribe = () => () => undefined;

/** How many History items the Account page shows. */
export const RECENT_COUNT = 5;

export function AccountPage() {
  const router = useRouter();
  const hydrated = useSyncExternalStore(noopSubscribe, () => true, () => false);
  const session = useSyncExternalStore(
    browserTokens.subscribe,
    () => browserTokens.session(),
    () => null,
  );
  const { store, state } = useSync();
  const recent = liveItems(state.history).slice(0, RECENT_COUNT);
  const [me, setMe] = useState<Me | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [confirming, setConfirming] = useState(false);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    if (hydrated && !session) router.replace(ACCOUNT_SIGN_IN_PATH);
  }, [hydrated, session, router]);

  const signedIn = session !== null;
  useEffect(() => {
    if (!signedIn) return;
    let cancelled = false;
    accountApi(browserTokens)
      .me()
      .then((value) => !cancelled && setMe(value))
      .catch((e: unknown) => {
        if (cancelled) return;
        if (e instanceof ApiError && e.kind === "signInRequired") router.replace(ACCOUNT_SIGN_IN_PATH);
        else setError(e instanceof ApiError ? e.message : MESSAGES.generic);
      });
    return () => {
      cancelled = true;
    };
  }, [signedIn, router]);

  async function deleteAccount() {
    setDeleting(true);
    setError(null);
    try {
      await accountApi(browserTokens).deleteAccount();
      await browserTokens.signOut();
      router.replace("/");
    } catch (e) {
      setError(e instanceof ApiError ? e.message : MESSAGES.generic);
      setDeleting(false);
      setConfirming(false);
    }
  }

  if (!hydrated || !session) return <div className="min-h-[420px]" />;

  return (
    <div className="mx-auto flex w-full max-w-[560px] flex-col gap-4 px-4 py-8 sm:px-6">
      <h1 className="font-display text-3xl">Account</h1>
      {error && (
        <p role="alert" className="flex items-center gap-2 text-sm text-error">
          <Alert className="size-4 shrink-0" /> {error}
        </p>
      )}

      <section className="flex items-center gap-4 rounded-2xl border border-hairline bg-surface p-4">
        <div className="size-16 shrink-0 overflow-hidden rounded-full bg-meaning p-2">
          <PixelCat mood="awake" />
        </div>
        <div className="min-w-0 flex-1">
          <p className="truncate font-medium" title={session.email}>
            {session.email}
          </p>
          <p className="text-sm text-muted">{me ? memberLine(me) : "Loading…"}</p>
        </div>
        <IconButton
          label="Sign out"
          variant="plain"
          icon={<SignOut />}
          onClick={() => {
            void browserTokens.signOut();
            router.replace("/");
          }}
        />
      </section>

      <section className="grid grid-cols-3 gap-3">
        {(me ? statTiles(me) : [null, null, null]).map((tile, i) => (
          <div key={tile?.label ?? i} className="rounded-2xl border border-hairline bg-surface p-3">
            <p className="text-xl font-medium tabular-nums">{tile?.value ?? "–"}</p>
            <p className="text-xs text-muted">{tile?.label ?? " "}</p>
          </div>
        ))}
      </section>

      <section aria-labelledby="account-history" className="flex flex-col gap-2">
        <div className="flex items-baseline justify-between px-1">
          <h2 id="account-history" className="text-[0.8125rem] font-semibold text-muted">
            History
          </h2>
          <Link href="/history" className="text-sm text-accent hover:underline">
            See all
          </Link>
        </div>
        {store && recent.length > 0 ? (
          <GlassList>
            {recent.map((item) => (
              <HistoryRow
                key={`${item.kind}:${item.text}`}
                item={item}
                tab="history"
                liked={isLiked(state.liked, item)}
                store={store}
              />
            ))}
          </GlassList>
        ) : (
          <p className="rounded-2xl border border-hairline bg-surface/70 p-4 text-center text-sm text-muted backdrop-blur-xl">
            Words and sentences you look up appear here.
          </p>
        )}
      </section>

      <section className="flex items-center gap-3 rounded-2xl border border-hairline bg-surface p-4">
        <div className="min-w-0 flex-1">
          <p className="font-medium">Delete account</p>
          <p className="text-sm text-muted">
            {confirming
              ? "This removes your account, history and liked items for good. Tap the red button again to confirm."
              : "Remove your account and everything saved in it."}
          </p>
        </div>
        <IconButton
          label={confirming ? "Confirm delete account" : "Delete account"}
          variant="plain"
          icon={<Trash className="text-error" />}
          className={confirming ? "text-error ring-2 ring-error" : ""}
          disabled={deleting}
          onClick={() => (confirming ? void deleteAccount() : setConfirming(true))}
        />
        {confirming && !deleting && (
          <button type="button" className="text-sm text-muted underline" onClick={() => setConfirming(false)}>
            Cancel
          </button>
        )}
      </section>
    </div>
  );
}
