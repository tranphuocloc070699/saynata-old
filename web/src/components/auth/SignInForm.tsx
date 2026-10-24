"use client";
/**
 * The /sign-in and /sign-up form (TASK-102, doc-23): Apple and Google first, then the 6-digit email code.
 * Both routes run the same flows (a new email or provider account is made on the first sign-in); only the words
 * differ. Google returns to /sign-in with the ID token in the address hash; Apple answers in a popup.
 */
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { ApiError, MESSAGES } from "@/lib/api";
import {
  APPLE_SERVICES_ID,
  GOOGLE_CLIENT_ID,
  authApi,
  browserTokens,
  isValidEmail,
  makeNonce,
  safeNextPath,
  type TokenResponse,
} from "@/lib/auth";
import { Alert } from "../icons";

export type FormMode = "signIn" | "signUp";

const COPY = {
  signIn: {
    title: "Log in",
    subtitle: "Welcome back. Pick up where you left off.",
    apple: "Continue with Apple",
    google: "Continue with Google",
    switchText: "New to Saynata?",
    switchLink: "Sign up",
    switchPath: "/sign-up",
  },
  signUp: {
    title: "Create your account",
    subtitle: "Free. Save words, sentences and your liked list.",
    apple: "Sign up with Apple",
    google: "Sign up with Google",
    switchText: "Already have an account?",
    switchLink: "Log in",
    switchPath: "/sign-in",
  },
} as const;

/** What the Google redirect needs after it comes back (sessionStorage: this tab only). */
const GOOGLE_STATE_KEY = "saynata.google-sign-in";
const APPLE_SCRIPT =
  "https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js";

type Step = { kind: "email" } | { kind: "code"; email: string };

export function SignInForm({ mode }: { mode: FormMode }) {
  const copy = COPY[mode];
  const router = useRouter();
  const params = useSearchParams();
  const next = params.get("next");

  const [step, setStep] = useState<Step>({ kind: "email" });
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState<null | "apple" | "google" | "email">(null);
  const [error, setError] = useState<string | null>(null);
  const codeInput = useRef<HTMLInputElement>(null);

  function finish(response: TokenResponse, to: string | null = next) {
    browserTokens.signedIn(response);
    router.replace(safeNextPath(to));
  }

  function fail(err: unknown) {
    setError(err instanceof ApiError ? err.message : MESSAGES.generic);
    setBusy(null);
  }

  // Back from Google: #id_token=…&state=… (or #error=…). In a timer so the state changes happen after the effect.
  useEffect(() => {
    const timer = window.setTimeout(() => {
      const hash = new URLSearchParams(window.location.hash.slice(1));
      if (!hash.has("id_token") && !hash.has("error")) return;
      window.history.replaceState(null, "", window.location.pathname + window.location.search);
      const saved = readGoogleState();
      const idToken = hash.get("id_token");
      if (hash.has("error") || !idToken || !saved || saved.state !== hash.get("state")) {
        if (hash.get("error") !== "access_denied") setError("Google sign-in did not finish. Try again.");
        return;
      }
      setBusy("google");
      authApi.google(idToken, saved.nonce).then((response) => finish(response, saved.next), fail);
    });
    return () => window.clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- runs once, on the return from Google
  }, []);

  useEffect(() => {
    if (step.kind === "code") codeInput.current?.focus();
  }, [step.kind]);

  async function google() {
    setError(null);
    setBusy("google");
    const nonce = await makeNonce();
    const state = crypto.randomUUID();
    try {
      sessionStorage.setItem(GOOGLE_STATE_KEY, JSON.stringify({ state, nonce: nonce.raw, next }));
    } catch {
      // Without sessionStorage the return cannot be checked; it fails there with a clear message.
    }
    const query = new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      response_type: "id_token",
      scope: "openid email",
      redirect_uri: `${window.location.origin}/sign-in`,
      nonce: nonce.hashed,
      state,
      prompt: "select_account",
    });
    window.location.assign(`https://accounts.google.com/o/oauth2/v2/auth?${query}`);
  }

  async function apple() {
    setError(null);
    setBusy("apple");
    try {
      const appleId = await loadAppleId();
      const nonce = await makeNonce();
      appleId.auth.init({
        clientId: APPLE_SERVICES_ID,
        scope: "email",
        redirectURI: `${window.location.origin}/sign-in`,
        nonce: nonce.hashed,
        usePopup: true,
      });
      const answer = await appleId.auth.signIn();
      const idToken = answer?.authorization?.id_token;
      if (!idToken) throw new Error("no id_token");
      finish(await authApi.apple(idToken, nonce.raw));
    } catch (err) {
      // Closing the popup is not an error worth showing.
      const cancelled = (err as { error?: string } | null)?.error === "popup_closed_by_user";
      if (cancelled) setBusy(null);
      else fail(err instanceof ApiError ? err : new ApiError("badRequest", "Apple sign-in did not finish. Try again."));
    }
  }

  async function sendCode(event: FormEvent) {
    event.preventDefault();
    const value = email.trim();
    if (!isValidEmail(value)) {
      setError("Enter a valid email address.");
      return;
    }
    setError(null);
    setBusy("email");
    try {
      await authApi.sendCode(value);
      setStep({ kind: "code", email: value });
      setCode("");
      setBusy(null);
    } catch (err) {
      fail(err);
    }
  }

  async function verify(event: FormEvent) {
    event.preventDefault();
    if (step.kind !== "code") return;
    if (!/^\d{6}$/.test(code)) {
      setError("Enter the 6-digit code from the email.");
      return;
    }
    setError(null);
    setBusy("email");
    try {
      finish(await authApi.verify(step.email, code));
    } catch (err) {
      fail(err);
    }
  }

  const switchHref = next ? `${copy.switchPath}?next=${encodeURIComponent(next)}` : copy.switchPath;
  const pill =
    "flex min-h-12 w-full cursor-pointer items-center justify-center gap-2.5 rounded-full border border-hairline bg-surface px-4 text-[0.95rem] font-medium text-ink transition-colors hover:border-accent/50 disabled:cursor-default disabled:opacity-60";
  const primary =
    "flex min-h-12 w-full cursor-pointer items-center justify-center rounded-full bg-accent px-4 font-medium text-on-accent shadow-sm disabled:cursor-default disabled:opacity-60";
  const field =
    "min-h-12 w-full rounded-2xl border border-hairline bg-bg px-4 text-ink outline-none placeholder:text-muted focus:border-accent";

  return (
    <section className="rounded-[22px] border border-hairline bg-surface p-6 shadow-[0_1px_2px_rgb(0_0_0/0.04),0_10px_30px_-12px_rgb(31_42_38/0.18)] sm:p-8">
      <h1 className="font-display text-[1.9rem] leading-tight text-ink">{copy.title}</h1>
      <p className="mt-1.5 text-ink-2">{copy.subtitle}</p>

      {step.kind === "email" ? (
        <>
          <div className="mt-6 flex flex-col gap-3">
            <button type="button" className={pill} disabled={busy !== null} onClick={() => void apple()}>
              <AppleLogo />
              {copy.apple}
            </button>
            <button type="button" className={pill} disabled={busy !== null} onClick={() => void google()}>
              <GoogleLogo />
              {copy.google}
            </button>
          </div>

          <div className="my-5 flex items-center gap-3 text-xs font-medium tracking-wider text-muted" aria-hidden="true">
            <span className="h-px flex-1 bg-hairline" />
            OR
            <span className="h-px flex-1 bg-hairline" />
          </div>

          <form onSubmit={(event) => void sendCode(event)} noValidate className="flex flex-col gap-3">
            <label className="flex flex-col gap-1.5 text-sm font-medium text-ink-2">
              Email
              <input
                type="email"
                name="email"
                autoComplete="email"
                inputMode="email"
                placeholder="you@example.com"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                className={field}
              />
            </label>
            <button type="submit" className={primary} disabled={busy !== null}>
              {busy === "email" ? "Sending…" : "Email me a code"}
            </button>
          </form>
        </>
      ) : (
        <form onSubmit={(event) => void verify(event)} noValidate className="mt-6 flex flex-col gap-3">
          <p className="text-ink-2">
            We sent a 6-digit code to <span className="font-medium text-ink">{step.email}</span>.
          </p>
          <label className="flex flex-col gap-1.5 text-sm font-medium text-ink-2">
            Code
            <input
              ref={codeInput}
              name="code"
              autoComplete="one-time-code"
              inputMode="numeric"
              maxLength={6}
              placeholder="123456"
              value={code}
              onChange={(event) => setCode(event.target.value.replace(/\D/g, "").slice(0, 6))}
              className={`${field} text-center font-mono text-xl tracking-[0.4em]`}
            />
          </label>
          <button type="submit" className={primary} disabled={busy !== null}>
            {busy === "email" ? "Checking…" : copy.title}
          </button>
          <button
            type="button"
            className="cursor-pointer self-center text-sm text-accent hover:underline"
            onClick={() => {
              setStep({ kind: "email" });
              setError(null);
            }}
          >
            Use another email
          </button>
        </form>
      )}

      <div aria-live="polite">
        {error && (
          <p role="alert" className="mt-4 flex items-start gap-2 text-sm text-error">
            <Alert className="mt-0.5 size-4 shrink-0" />
            <span>{error}</span>
          </p>
        )}
      </div>

      <p className="mt-6 text-center text-sm text-ink-2">
        {copy.switchText}{" "}
        <Link href={switchHref} className="font-semibold text-accent hover:underline">
          {copy.switchLink}
        </Link>
      </p>
      <p className="mt-3 text-center text-xs text-muted">By continuing you agree to the Terms and Privacy Policy.</p>
    </section>
  );
}

function readGoogleState(): { state: string; nonce: string; next: string | null } | null {
  try {
    const raw = sessionStorage.getItem(GOOGLE_STATE_KEY);
    sessionStorage.removeItem(GOOGLE_STATE_KEY);
    return raw ? (JSON.parse(raw) as { state: string; nonce: string; next: string | null }) : null;
  } catch {
    return null;
  }
}

// Apple JS (Sign in with Apple on the web). It loads only when the Apple button is pressed.

interface AppleIdAuth {
  auth: {
    init(config: { clientId: string; scope: string; redirectURI: string; nonce: string; usePopup: boolean }): void;
    signIn(): Promise<{ authorization?: { id_token?: string } } | undefined>;
  };
}

let appleScript: Promise<AppleIdAuth> | null = null;

function loadAppleId(): Promise<AppleIdAuth> {
  appleScript ??= new Promise<AppleIdAuth>((resolve, reject) => {
    const script = document.createElement("script");
    script.src = APPLE_SCRIPT;
    script.async = true;
    script.onload = () => {
      const appleId = (window as unknown as { AppleID?: AppleIdAuth }).AppleID;
      if (appleId) resolve(appleId);
      else reject(new Error("AppleID missing"));
    };
    script.onerror = () => {
      appleScript = null;
      reject(new ApiError("network", MESSAGES.network));
    };
    document.head.appendChild(script);
  });
  return appleScript;
}

function AppleLogo() {
  return (
    <svg viewBox="0 0 24 24" className="size-5 text-black dark:text-white" aria-hidden="true" focusable="false">
      <path
        fill="currentColor"
        d="M16.4 12.6c0-2.6 2.1-3.8 2.2-3.9-1.2-1.8-3.1-2-3.7-2-1.6-.2-3.1.9-3.9.9-.8 0-2-.9-3.4-.9-1.7 0-3.3 1-4.2 2.6-1.8 3.1-.5 7.7 1.3 10.2.9 1.2 1.9 2.6 3.2 2.6 1.3-.1 1.8-.8 3.3-.8 1.6 0 2 .8 3.4.8 1.4 0 2.3-1.3 3.1-2.5 1-1.4 1.4-2.8 1.4-2.9 0 0-2.7-1-2.7-4.1zM13.8 5c.7-.9 1.2-2 1.1-3.2-1 0-2.3.7-3 1.6-.7.8-1.2 2-1.1 3.1 1.1.1 2.3-.6 3-1.5z"
      />
    </svg>
  );
}

function GoogleLogo() {
  return (
    <svg viewBox="0 0 24 24" className="size-5" aria-hidden="true" focusable="false">
      <path fill="#4285F4" d="M22.6 12.2c0-.8-.1-1.5-.2-2.2H12v4.2h5.9c-.3 1.4-1 2.5-2.2 3.3v2.7h3.6c2.1-1.9 3.3-4.8 3.3-8z" />
      <path fill="#34A853" d="M12 23c3 0 5.5-1 7.3-2.7l-3.6-2.7c-1 .7-2.2 1.1-3.7 1.1-2.9 0-5.3-1.9-6.2-4.5H2.1v2.8C3.9 20.6 7.7 23 12 23z" />
      <path fill="#FBBC05" d="M5.8 14.2c-.2-.7-.4-1.4-.4-2.2s.1-1.5.4-2.2V7H2.1C1.4 8.5 1 10.2 1 12s.4 3.5 1.1 5l3.7-2.8z" />
      <path fill="#EA4335" d="M12 5.4c1.6 0 3.1.6 4.2 1.7l3.2-3.2C17.5 2.1 15 1 12 1 7.7 1 3.9 3.4 2.1 7l3.7 2.8C6.7 7.3 9.1 5.4 12 5.4z" />
    </svg>
  );
}
