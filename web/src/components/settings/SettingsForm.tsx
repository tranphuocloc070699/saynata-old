"use client";
/** The two settings cards (TASK-102.7). Every change applies at once; a signed-in change is also sent to the account. */
import { useEffect, useId, useSyncExternalStore } from "react";
import { browserTokens } from "@/lib/auth";
import { LANGUAGES, isLanguageCode } from "@/lib/languages";
import { settingsStore, useSettings, type ShowTranslation } from "@/lib/settings";

const SHOW_OPTIONS: { value: ShowTranslation; label: string }[] = [
  { value: "collapsed", label: "Collapsed" },
  { value: "alwaysOpen", label: "Always open" },
  { value: "remember", label: "Remember" },
];

export function SettingsForm() {
  const [settings, update] = useSettings();
  const session = useSyncExternalStore(
    browserTokens.subscribe,
    () => browserTokens.session(),
    () => null,
  );
  // Load the account's settings when the page opens, and again if the user signs in here.
  const signedIn = session !== null;
  useEffect(() => {
    if (signedIn) void settingsStore.load();
  }, [signedIn]);

  const languageId = useId();
  const syncId = useId();
  return (
    <div className="mt-6 flex flex-col gap-4">
      <section className="flex flex-col gap-4 rounded-2xl border border-hairline bg-surface p-5">
        <h2 className="text-lg font-semibold">Translation</h2>
        <div className="flex flex-col gap-1.5">
          <label htmlFor={languageId} className="text-sm font-medium text-ink-2">
            Language
          </label>
          <select
            id={languageId}
            value={settings.targetLanguage}
            onChange={(event) => isLanguageCode(event.target.value) && update({ targetLanguage: event.target.value })}
            className="min-h-11 rounded-xl border border-hairline bg-bg px-3 text-ink"
          >
            {LANGUAGES.map((language) => (
              <option key={language.code} value={language.code}>
                {language.name}
              </option>
            ))}
          </select>
        </div>
        <div role="radiogroup" aria-label="Show translation" className="flex flex-col gap-1.5">
          <span className="text-sm font-medium text-ink-2">Show translation</span>
          <div className="flex rounded-full bg-tag p-1">
            {SHOW_OPTIONS.map((option) => {
              const selected = settings.showTranslation === option.value;
              return (
                <button
                  key={option.value}
                  type="button"
                  role="radio"
                  aria-checked={selected}
                  onClick={() => update({ showTranslation: option.value })}
                  className={`min-h-9 flex-1 cursor-pointer rounded-full px-2 text-sm font-medium ${
                    selected ? "bg-surface text-ink shadow-sm" : "text-muted hover:text-ink"
                  }`}
                >
                  {option.label}
                </button>
              );
            })}
          </div>
        </div>
      </section>
      <section className="flex items-center gap-4 rounded-2xl border border-hairline bg-surface p-5">
        <div className="flex-1">
          <h2 className="text-lg font-semibold">History</h2>
          <p id={syncId} className="mt-1 text-sm text-muted">
            Keep your history the same on phone, Mac and web.
          </p>
        </div>
        <span className="text-sm font-medium text-ink-2" aria-hidden>
          Sync history
        </span>
        <button
          type="button"
          role="switch"
          aria-checked={settings.syncHistory}
          aria-label="Sync history"
          aria-describedby={syncId}
          onClick={() => update({ syncHistory: !settings.syncHistory })}
          className={`relative h-7 w-12 shrink-0 cursor-pointer rounded-full transition-colors motion-reduce:transition-none ${
            settings.syncHistory ? "bg-accent" : "bg-hairline"
          }`}
        >
          <span
            className={`absolute top-0.5 left-0.5 size-6 rounded-full bg-surface shadow-sm transition-transform motion-reduce:transition-none ${
              settings.syncHistory ? "translate-x-5" : ""
            }`}
          />
        </button>
      </section>
    </div>
  );
}
