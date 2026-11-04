import type { Metadata } from "next";
import Link from "next/link";
import { CONTACT_EMAIL, LegalPage, LegalSection } from "@/components/legal/LegalPage";

export const metadata: Metadata = {
  title: "Privacy policy · Saynata",
  description: "What Saynata keeps, why, who helps us run it, how long we keep it, and how to delete your account.",
};

const mail = `mailto:${CONTACT_EMAIL}`;

/**
 * /privacy (TASK-102.4, doc-23). Covers the website, the iPhone and Mac apps and the browser extension.
 * Keep it true to the code: tables and lifetimes in doc-17 and doc-22, the analytics rule in docs/analytics/events.md.
 */
export default function Page() {
  return (
    <LegalPage
      title="Privacy policy"
      intro="Saynata helps you learn English: you look up a word or a sentence and read a simple English explanation. This page explains what we keep, why, who helps us run Saynata, how long we keep it, and how you delete your account. It covers the website, the iPhone and Mac apps and the browser extension."
    >
      <LegalSection title="The short version">
        <ul className="list-disc space-y-1 pl-5">
          <li>You can use Saynata without an account. A guest sees answers we already have.</li>
          <li>With an account we keep your email, how you sign in, your History (if sync is on), your Liked items and your settings.</li>
          <li>To write a new explanation, the text you look up goes to an AI service (DeepSeek, or Gemini as a backup), without your email or name.</li>
          <li>Usage counts (PostHog) and crash reports (Sentry) never contain the words or sentences you look up.</li>
          <li>We do not sell your data and we do not show ads.</li>
          <li>You can delete your account at any time, in the app or on the website.</li>
        </ul>
      </LegalSection>

      <LegalSection title="What we keep and why">
        <ul className="list-disc space-y-2 pl-5">
          <li>
            <strong className="text-ink">Your email address</strong>, to sign you in (a one-time code or link) and to
            tell your account apart from others.
          </li>
          <li>
            <strong className="text-ink">How you sign in.</strong> If you use Sign in with Apple or Google, we keep the
            account ID they give us, so the same person always gets the same account. We never see your Apple or Google
            password.
          </li>
          <li>
            <strong className="text-ink">History</strong>: the words and sentences you looked up, so they appear on all
            your devices. Only when &quot;Sync history&quot; is on, and only your latest 1,000.
          </li>
          <li>
            <strong className="text-ink">Liked items</strong>: the words and sentences you star.
          </li>
          <li>
            <strong className="text-ink">Settings</strong>: your language, how the translation line opens, and whether
            History syncs.
          </li>
          <li>
            <strong className="text-ink">AI use</strong>: for each new AI answer, the time, the model, the size of the
            request and its cost. We use it to keep a fair daily limit per person and to watch our costs. It does not
            hold the text you looked up.
          </li>
          <li>
            <strong className="text-ink">Shared explanations.</strong> When a new word or sentence is explained, the
            text and its explanation are saved in a shared library, so the next learner gets the answer at once. This
            library is not linked to you or your account.
          </li>
          <li>
            <strong className="text-ink">Your IP address</strong> is used for a short time to stop abuse (too many
            requests). It is not saved in our database.
          </li>
        </ul>
        <p>Without an account, History, Liked items and settings stay on your device only.</p>
      </LegalSection>

      <LegalSection title="Who helps us run Saynata">
        <ul className="list-disc space-y-2 pl-5">
          <li>
            <strong className="text-ink">Our server.</strong> The website, the account data and the shared library live
            on our own server (a rented virtual server with a Postgres database). Only the developer can reach it.
          </li>
          <li>
            <strong className="text-ink">DeepSeek and Gemini (AI).</strong> When we have no answer yet, the text you
            looked up is sent to DeepSeek to write the explanation. If DeepSeek fails, the same text goes to Google
            Gemini instead. We send only the text and our instructions, never your email, name or account.
          </li>
          <li>
            <strong className="text-ink">PostHog (usage).</strong> We count how features are used, for example
            &quot;a word was looked up&quot;, &quot;the translation line was opened&quot; or &quot;sign-in worked&quot;,
            so we know what helps learners. An event carries only fixed values such as the kind of lookup, its length
            group (for example &quot;1-20 characters&quot;), your language and the platform.{" "}
            <strong className="text-ink">
              It never carries what you looked up, typed, selected or copied, a page address or your email.
            </strong>{" "}
            After sign-in it is linked to your account number, never your email or name. Screen recording is off.
          </li>
          <li>
            <strong className="text-ink">Sentry (crash reports).</strong> When the app, the website or the server
            breaks, Sentry gets the error, the device or browser type and the app version, so we can fix it. We remove
            request bodies, cookies, query strings and the word from web addresses before a report is sent, so it does
            not hold your text.
          </li>
          <li>
            <strong className="text-ink">Resend</strong> sends the sign-in emails (your email address and the code or
            link).
          </li>
          <li>
            <strong className="text-ink">Apple and Google</strong>, only if you choose to sign in with them.
          </li>
        </ul>
        <p>These services may process data outside your country. We give each one only what it needs for its job.</p>
      </LegalSection>

      <LegalSection title="How long we keep it">
        <ul className="list-disc space-y-1 pl-5">
          <li>Email, sign-in accounts, History, Liked items and settings: until you remove them or delete your account.</li>
          <li>History on the server: deleted at once when you turn &quot;Sync history&quot; off.</li>
          <li>Sign-in codes: 10 minutes. Sign-in links: 15 minutes. A signed-in session: 60 days after its last use.</li>
          <li>
            AI use records: kept to count limits and costs. After you delete your account they keep only a number that
            no longer leads to anyone.
          </li>
          <li>Shared explanations: kept, since they are not linked to anyone.</li>
          <li>Usage events (PostHog): up to 1 year. Crash reports (Sentry): up to 90 days.</li>
        </ul>
      </LegalSection>

      <LegalSection title="Delete your account">
        <p>
          In the iPhone or Mac app, open <strong className="text-ink">Settings</strong>, then{" "}
          <strong className="text-ink">Delete account</strong>. On the website, open{" "}
          <Link href="/account" className="font-semibold text-accent hover:underline">
            Account
          </Link>
          , then <strong className="text-ink">Delete account</strong>. This deletes at once your email, your sign-in
          accounts, your sessions, your History, your Liked items and your settings. It cannot be undone.
        </p>
        <p>
          You can also write to{" "}
          <a href={mail} className="font-semibold text-accent hover:underline">
            {CONTACT_EMAIL}
          </a>{" "}
          from the email of your account, and we will delete it for you.
        </p>
      </LegalSection>

      <LegalSection title="Your rights">
        <p>
          You can ask what we keep about you, ask us to correct it, or ask for a copy. Write to{" "}
          <a href={mail} className="font-semibold text-accent hover:underline">
            {CONTACT_EMAIL}
          </a>
          .
        </p>
      </LegalSection>

      <LegalSection title="Children">
        <p>Saynata is not made for children under 13, and we do not knowingly keep their data.</p>
      </LegalSection>

      <LegalSection title="Changes">
        <p>
          When this policy changes, we change the date at the top. A big change is also shown in the app or on the
          website.
        </p>
      </LegalSection>
    </LegalPage>
  );
}
