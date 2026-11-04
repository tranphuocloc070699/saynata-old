import type { Metadata } from "next";
import Link from "next/link";
import { CONTACT_EMAIL, LegalPage, LegalSection } from "@/components/legal/LegalPage";

export const metadata: Metadata = {
  title: "Terms of use · Saynata",
  description: "The rules for using Saynata: the website, the iPhone and Mac apps and the browser extension.",
};

/** /terms (TASK-102.4, doc-23). Plain terms of use for every Saynata app. */
export default function Page() {
  return (
    <LegalPage
      title="Terms of use"
      intro="These terms are the rules for using Saynata: the website, the iPhone and Mac apps and the browser extension. By using Saynata you agree to them."
    >
      <LegalSection title="What Saynata is">
        <p>
          Saynata is a learning tool. It explains English words and sentences in simple English, with a short line in
          your language. It is a small project made and run by one developer.
        </p>
      </LegalSection>

      <LegalSection title="AI answers can be wrong">
        <p>
          Many explanations are written by AI. We check and improve them, but an answer can still be wrong or
          incomplete. Use Saynata to learn, not for legal, medical, financial or other important decisions.
        </p>
      </LegalSection>

      <LegalSection title="Your account">
        <ul className="list-disc space-y-1 pl-5">
          <li>You can use Saynata as a guest. Some features, like new AI answers and sync, need an account.</li>
          <li>Keep your email account safe: anyone who can read it can sign in as you.</li>
          <li>You can delete your account at any time (see the privacy policy).</li>
        </ul>
      </LegalSection>

      <LegalSection title="Fair use">
        <p>To keep Saynata free and fast for everyone, please do not:</p>
        <ul className="list-disc space-y-1 pl-5">
          <li>send automated requests, copy the dictionary in bulk, or get around the daily limits;</li>
          <li>try to break into, slow down or harm the service or other people&apos;s accounts;</li>
          <li>use Saynata to send illegal, hateful or harmful content.</li>
        </ul>
        <p>We may limit or block an account that does this.</p>
      </LegalSection>

      <LegalSection title="Content">
        <p>
          The text you look up stays yours. You let us use it to write the explanation and to keep that explanation in
          the shared library for other learners (it is not linked to you). The explanations, pictures and design of
          Saynata belong to Saynata or to the people who made them, and are for your own learning.
        </p>
      </LegalSection>

      <LegalSection title="No guarantee">
        <p>
          Saynata is given &quot;as is&quot;. We try to keep it working, but it may sometimes be down, slow or changed,
          and a feature may be removed. As far as the law allows, we are not responsible for loss caused by using it.
        </p>
      </LegalSection>

      <LegalSection title="Privacy">
        <p>
          How we handle your data is in the{" "}
          <Link href="/privacy" className="font-semibold text-accent hover:underline">
            privacy policy
          </Link>
          .
        </p>
      </LegalSection>

      <LegalSection title="Changes and contact">
        <p>
          When these terms change, we change the date at the top. Questions? Write to{" "}
          <a href={`mailto:${CONTACT_EMAIL}`} className="font-semibold text-accent hover:underline">
            {CONTACT_EMAIL}
          </a>
          .
        </p>
      </LegalSection>
    </LegalPage>
  );
}
