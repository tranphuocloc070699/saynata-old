import type { Metadata } from "next";
import { SiteHeader } from "@/components/SiteHeader";
import { AccountPage } from "@/components/auth/AccountPage";

export const metadata: Metadata = { title: "Account · Saynata" };

/** /account (TASK-102.8, doc-23): the signed-in learner's profile, counts and delete. Guests go to /sign-in. */
export default function Page() {
  return (
    <>
      <SiteHeader />
      <main className="flex-1">
        <AccountPage />
      </main>
    </>
  );
}
