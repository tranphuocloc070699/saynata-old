"use client";
/** React side of lib/sync.ts: the store of the signed-in account and its state; both are null/empty for a guest. */
import { useEffect, useSyncExternalStore } from "react";
import { browserTokens } from "./auth";
import { emptyState, syncStoreFor, type SyncState, type SyncStore } from "./sync";

const EMPTY = emptyState();
const noopSubscribe = () => () => undefined;

export function useSync(): { store: SyncStore | null; state: SyncState; hydrated: boolean } {
  // The server and the first client render know nothing of the session, so the HTML matches.
  const hydrated = useSyncExternalStore(
    noopSubscribe,
    () => true,
    () => false,
  );
  const session = useSyncExternalStore(
    browserTokens.subscribe,
    () => browserTokens.session(),
    () => null,
  );
  const store = session ? syncStoreFor(session.email) : null;
  useEffect(() => store?.start(), [store]);
  const state = useSyncExternalStore(
    store ? store.subscribe : noopSubscribe,
    store ? store.snapshot : () => EMPTY,
    () => EMPTY,
  );
  return { store, state, hydrated };
}
