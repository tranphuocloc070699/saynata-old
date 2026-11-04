// Sentry in the edge runtime, loaded by src/instrumentation.ts (TASK-128.4).
import * as Sentry from "@sentry/nextjs";
import { sentryOptions } from "./lib/sentry";

Sentry.init(sentryOptions);
