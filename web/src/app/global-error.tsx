"use client";

// Reports a render error anywhere in the app to Sentry, then shows Next's plain error page (TASK-128.4).
import * as Sentry from "@sentry/nextjs";
import NextError from "next/error";
import { useEffect } from "react";

export default function GlobalError({ error }: { error: Error & { digest?: string } }) {
  useEffect(() => {
    Sentry.captureException(error);
  }, [error]);

  return (
    <html lang="en">
      <body>
        {/* The App Router has no status code for a render error, so 0 shows the generic message. */}
        <NextError statusCode={0} />
      </body>
    </html>
  );
}
