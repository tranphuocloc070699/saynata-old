import type { Metadata } from "next";
import { SiteHeader } from "@/components/SiteHeader";
import { SettingsForm } from "@/components/settings/SettingsForm";

export const metadata: Metadata = { title: "Settings · Saynata" };

/** /settings (TASK-102.7, doc-23): translation and history options; they follow the account when signed in. */
export default function Page() {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto w-full max-w-[640px] flex-1 px-4 pt-8 pb-16 sm:px-6">
        <h1 className="font-display text-3xl">Settings</h1>
        <SettingsForm />
      </main>
    </>
  );
}
