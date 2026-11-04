// Sentry in the browser (TASK-128.4). Options and privacy rules: src/lib/sentry.ts.
import * as Sentry from "@sentry/nextjs";
import { sentryOptions } from "./lib/sentry";

Sentry.init(sentryOptions);

export const onRouterTransitionStart = Sentry.captureRouterTransitionStart;
