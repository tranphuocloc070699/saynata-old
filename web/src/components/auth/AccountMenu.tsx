"use client";
/**
 * The header's account corner (TASK-102.8, doc-23, option B): a guest sees the "Sign in" pill; a signed-in user sees
 * a History icon button and an avatar circle (the first letter of the email) that opens a menu: the email (small,
 * muted), then Settings, Account and Sign out. The email never sits in the header itself.
 * The menu closes on Escape and on a click outside, and works with the arrow keys.
 */
import Link from "next/link";
import { useEffect, useId, useRef, useState, useSyncExternalStore, type KeyboardEvent, type ReactNode } from "react";
import { avatarLetter } from "@/lib/account";
import { browserTokens } from "@/lib/auth";
import { Clock, Gear, SignOut, User } from "../icons";

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
    <div className="ml-auto flex items-center gap-1">
      <Link
        href="/history"
        aria-label="History"
        title="History"
        className="grid size-11 shrink-0 place-items-center rounded-full text-muted hover:text-ink"
      >
        <Clock className="size-[18px]" />
      </Link>
      <AvatarMenu email={session.email} />
    </div>
  );
}

const noopSubscribe = () => () => undefined;

function AvatarMenu({ email }: { email: string }) {
  const [open, setOpen] = useState(false);
  const wrap = useRef<HTMLDivElement>(null);
  const button = useRef<HTMLButtonElement>(null);
  const menu = useRef<HTMLDivElement>(null);
  const menuId = useId();

  useEffect(() => {
    if (!open) return;
    const items = menu.current?.querySelectorAll<HTMLElement>('[role="menuitem"]');
    items?.[0]?.focus();
    const onPointerDown = (event: PointerEvent) => {
      if (!wrap.current?.contains(event.target as Node)) setOpen(false);
    };
    document.addEventListener("pointerdown", onPointerDown);
    return () => document.removeEventListener("pointerdown", onPointerDown);
  }, [open]);

  const close = (focusButton: boolean) => {
    setOpen(false);
    if (focusButton) button.current?.focus();
  };

  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.key === "Escape") {
      event.stopPropagation();
      close(true);
      return;
    }
    if (event.key === "Tab") {
      setOpen(false);
      return;
    }
    const items = Array.from(menu.current?.querySelectorAll<HTMLElement>('[role="menuitem"]') ?? []);
    const at = items.indexOf(document.activeElement as HTMLElement);
    const move = (to: number) => {
      event.preventDefault();
      items[(to + items.length) % items.length]?.focus();
    };
    if (event.key === "ArrowDown") move(at + 1);
    else if (event.key === "ArrowUp") move(at - 1);
    else if (event.key === "Home") move(0);
    else if (event.key === "End") move(items.length - 1);
  };

  return (
    <div ref={wrap} className="relative" onKeyDown={onKeyDown}>
      <button
        ref={button}
        type="button"
        aria-label="Account menu"
        title="Account"
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={open ? menuId : undefined}
        onClick={() => setOpen((value) => !value)}
        className="grid size-11 shrink-0 cursor-pointer place-items-center rounded-full"
      >
        <span
          aria-hidden="true"
          className="grid size-9 place-items-center rounded-full bg-accent text-sm font-semibold text-on-accent"
        >
          {avatarLetter(email)}
        </span>
      </button>
      {open && (
        <div
          ref={menu}
          id={menuId}
          role="menu"
          aria-label="Account"
          className="absolute top-full right-0 z-30 mt-1 flex w-60 flex-col rounded-2xl border border-hairline bg-surface/90 p-1.5 shadow-lg backdrop-blur-xl"
        >
          <p className="truncate px-3 pt-2 pb-2 text-xs text-muted" title={email}>
            {email}
          </p>
          <div role="separator" className="mx-1 mb-1 h-px bg-hairline" />
          <MenuLink href="/settings" icon={<Gear />} onPick={() => close(false)}>
            Settings
          </MenuLink>
          <MenuLink href="/account" icon={<User />} onPick={() => close(false)}>
            Account
          </MenuLink>
          <button
            type="button"
            role="menuitem"
            onClick={() => {
              close(false);
              void browserTokens.signOut();
            }}
            className={ITEM}
          >
            <SignOut className="size-[18px] text-muted" />
            Sign out
          </button>
        </div>
      )}
    </div>
  );
}

const ITEM =
  "flex min-h-11 w-full cursor-pointer items-center gap-3 rounded-xl px-3 text-left text-sm text-ink hover:bg-meaning focus-visible:bg-meaning";

function MenuLink({ href, icon, onPick, children }: { href: string; icon: ReactNode; onPick: () => void; children: ReactNode }) {
  return (
    <Link href={href} role="menuitem" onClick={onPick} className={ITEM}>
      <span className="size-[18px] text-muted">{icon}</span>
      {children}
    </Link>
  );
}
