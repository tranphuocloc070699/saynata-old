"use client";
/** The header's account corner (TASK-102, doc-23): "Sign in" for a guest, the email and a sign-out button when signed in. */
import Link from "next/link";
import { useSyncExternalStore } from "react";
import { browserTokens } from "@/lib/auth";
import { IconButton } from "../IconButton";
import { SignOut } from "../icons";

export function AccountMenu() {
  // The server and the first client render show nothing, so the HTML matches; the session is in localStorage.
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
  if (!hydrated) return <div className="ml-auto h-11" />;
  if (!session) {
    return (
      <Link
        href="/sign-in"
        className="ml-auto inline-flex min-h-9 items-center rounded-full border border-hairline bg-surface px-3.5 text-sm text-ink-2 hover:border-accent/50 hover:text-accent"
      >
        Sign in
      </Link>
    );
  }
  return (
    <div className="ml-auto flex min-w-0 items-center gap-1">
      <span className="truncate text-sm text-muted" title={session.email}>
        {session.email}
      </span>
      <IconButton
        label="Sign out"
        variant="plain"
        icon={<SignOut />}
        onClick={() => void browserTokens.signOut()}
      />
    </div>
  );
}

const noopSubscribe = () => () => undefined;
