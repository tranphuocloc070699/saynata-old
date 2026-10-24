import type { Metadata } from "next";
import { Suspense } from "react";
import { CatRoom } from "@/components/CatRoom";
import { SiteHeader } from "@/components/SiteHeader";
import { SignInForm } from "@/components/auth/SignInForm";

export const metadata: Metadata = { title: "Sign up · Saynata" };

/** /sign-up (TASK-102, doc-23): the cat room on the left, the form on the right; under 760 px only the form. */
export default function Page() {
  return (
    <>
      <SiteHeader />
      <main className="cat-login-layout flex-1">
        <CatRoom />
        <div className="cat-login-layout__form">
          <Suspense fallback={<div className="min-h-[420px]" />}>
            <SignInForm mode="signUp" />
          </Suspense>
        </div>
      </main>
    </>
  );
}
