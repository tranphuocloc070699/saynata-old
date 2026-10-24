import Image from "next/image";
import Link from "next/link";
import { AccountMenu } from "./auth/AccountMenu";

/** The logo, which goes home, and the account corner. Shared by the homepage and the sign-in pages. */
export function SiteHeader() {
  return (
    <header className="mx-auto flex w-full max-w-[1224px] items-center gap-2.5 px-4 pt-5 sm:px-6">
      <Link href="/" className="flex items-center gap-2.5">
        <Image src="/logo.svg" alt="" width={32} height={32} className="rounded-[9px]" priority />
        <span className="font-display text-[1.35rem] leading-none">Saynata</span>
      </Link>
      <AccountMenu />
    </header>
  );
}
