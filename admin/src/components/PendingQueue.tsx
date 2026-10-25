import { useApiUrl, useCustom, useInfiniteList, useInvalidate } from "@refinedev/core";
import { Check, Loader2, Play, Trash2, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import type { PrefillOverview, PrefillQueueItem, PrefillRunSummary, PrefillSchedule } from "@/api/types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { httpClient } from "@/providers/dataProvider";

const PAGE_SIZE = 50;
const RESOURCE = "prefill/items";

// Where a queue row came from, in plain words.
const SOURCES: Record<string, string> = {
  "sentence-words": "In a sentence",
  "common-sentences": "Common sentences",
  "scowl-70": "Common words",
  "oewn-2025": "Phrases",
};

const VIETNAM_OFFSET_HOURS = 7;

function hhmm(date: Date, offsetHours: number) {
  const shifted = new Date(date.getTime() + offsetHours * 3_600_000);
  return `${String(shifted.getUTCHours()).padStart(2, "0")}:${String(shifted.getUTCMinutes()).padStart(2, "0")}`;
}

// "today 20:00 UTC (03:00 Vietnam), in 3 h". The day word is for UTC, the server's clock.
export function nextRunText(nextRunAt: string, now: Date = new Date()) {
  const next = new Date(nextRunAt);
  const days = Math.round((Date.UTC(next.getUTCFullYear(), next.getUTCMonth(), next.getUTCDate()) -
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())) / 86_400_000);
  const day = days === 0 ? "today" : days === 1 ? "tomorrow" : next.toISOString().slice(0, 10);
  const minutes = Math.max(0, Math.round((next.getTime() - now.getTime()) / 60_000));
  const wait = minutes < 60 ? `in ${minutes} min` : `in ${Math.round(minutes / 60)} h`;
  return `${day} ${hhmm(next, 0)} UTC (${hhmm(next, VIETNAM_OFFSET_HOURS)} Vietnam), ${wait}`;
}

function sourceNames(sources: string[]) {
  return sources.map((source) => `"${SOURCES[source] ?? source}"`).join(", ");
}

// The footer line that says when pending items get answered.
function ScheduleNote({ schedule, maxUsdPerRun }: { schedule?: PrefillSchedule; maxUsdPerRun?: number }) {
  if (!schedule) return null;
  if (!schedule.on || !schedule.nextRunAt) {
    return <p>The night job is off (PREFILL_CRON is empty). Pending items run only by hand.</p>;
  }
  return (
    <>
      <p className="text-foreground">
        Next night run: {nextRunText(schedule.nextRunAt)}
        {maxUsdPerRun != null && ` · cap $${maxUsdPerRun.toFixed(2)}`}
      </p>
      <p>
        The night run answers only {sourceNames(schedule.sources)} items. Other sources
        wait until you run them by hand.
      </p>
    </>
  );
}

const MAX_CAP_USD = 10; // the backend refuses more (AdminPrefillController.MAX_ALLOWED_USD)
const POLL_MS = 5_000;

function lastRunText(run: PrefillRunSummary) {
  const when = run.finishedAt.slice(0, 16).replace("T", " ");
  return `Last run (${run.trigger}, ${when} UTC): ${run.done} done, ${run.failed} failed, $${run.spentUsd.toFixed(2)} · stopped: ${run.stoppedBecause.replace("-", " ")}`;
}

// Starts a prefill run now (TASK-83.17): all pending sources or one, with an optional cap. Empty cap = the server's
// PREFILL_MAX_USD_PER_RUN. The run goes on in the background on the server; the footer polls while it runs.
function RunNow({ overview, onStarted }: { overview?: PrefillOverview; onStarted: () => void }) {
  const apiUrl = useApiUrl();
  const [source, setSource] = useState("");
  const [cap, setCap] = useState("");
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState<string>();
  const pendingSources = (overview?.bySource ?? []).filter((s) => (s.byStatus.pending ?? 0) > 0);
  const running = !!overview?.running;

  async function start() {
    const usd = Number(cap);
    if (cap && !(usd > 0 && usd <= MAX_CAP_USD)) {
      setError(`The cap must be more than $0 and at most $${MAX_CAP_USD}.`);
      return;
    }
    // Built by hand: the backend reads a repeated "source", and axios would send "source[]".
    const params = new URLSearchParams();
    if (source) params.append("source", source);
    if (cap) params.set("maxUsd", cap);
    const query = params.toString();
    setStarting(true);
    setError(undefined);
    try {
      await httpClient.post(`${apiUrl}/prefill/run${query ? `?${query}` : ""}`, {}, { headers: { "Content-Type": "application/json" } });
      onStarted();
    } catch (e) {
      setError((e as Error).message || "Could not start the run.");
    } finally {
      setStarting(false);
    }
  }

  const fieldClass = "h-9 rounded-lg border border-border bg-card px-2 text-sm text-foreground";
  return (
    <div className="space-y-1">
      <div className="flex flex-wrap items-center gap-2">
        <select aria-label="Source to run" className={`${fieldClass} min-w-40 flex-1`} value={source} onChange={(e) => setSource(e.target.value)}>
          <option value="">All pending sources ({pendingSources.length})</option>
          {pendingSources.map((s) => (
            <option key={s.source} value={s.source}>
              {SOURCES[s.source] ?? s.source} ({s.byStatus.pending.toLocaleString("en-US")})
            </option>
          ))}
        </select>
        <input
          aria-label="Cap in US dollars"
          title="The most this run may spend, in US dollars"
          className={`${fieldClass} w-24`}
          type="number"
          min="0.01"
          max={MAX_CAP_USD}
          step="0.05"
          placeholder={overview?.maxUsdPerRun != null ? `$${overview.maxUsdPerRun.toFixed(2)}` : "cap"}
          value={cap}
          onChange={(e) => {
            setCap(e.target.value);
            setError(undefined);
          }}
        />
        <Button
          size="icon"
          variant="outline"
          aria-label="Run prefill now"
          title={running ? "A run is going" : "Run prefill now"}
          disabled={running || starting}
          onClick={start}
        >
          {running || starting ? <Loader2 className="h-4 w-4 animate-spin" /> : <Play className="h-4 w-4" />}
        </Button>
      </div>
      {error && (
        <p role="alert" className="text-destructive">
          {error}
        </p>
      )}
      {running ? (
        <p role="status" className="text-foreground">Running… the list refreshes every few seconds.</p>
      ) : (
        overview?.lastRuns?.[0] && <p>{lastRunText(overview.lastRuns[0])}</p>
      )}
    </div>
  );
}

interface Props {
  kind: "word" | "sentence";
  query: string;
}

// The Pending choice (TASK-101): words and sentences in the prefill queue (TASK-100), not in the database yet.
// The night job answers them; then they leave this list and show up as normal rows. A row can be taken out of the
// queue (the server keeps it as "skipped", so the same word is not queued again).
export function PendingQueue({ kind, query }: Props) {
  const apiUrl = useApiUrl();
  const invalidate = useInvalidate();
  const [confirming, setConfirming] = useState<number>();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();

  const filters = [
    { field: "kind", operator: "eq" as const, value: kind },
    { field: "status", operator: "eq" as const, value: "pending" },
    ...(query ? [{ field: "q", operator: "contains" as const, value: query }] : []),
  ];
  const { query: listQuery, result } = useInfiniteList<PrefillQueueItem>({
    resource: RESOURCE,
    pagination: { currentPage: 1, pageSize: PAGE_SIZE },
    filters,
    queryOptions: {
      getNextPageParam: (lastPage, allPages) =>
        allPages.reduce((count, page) => count + page.data.length, 0) < (lastPage.total ?? 0) ? allPages.length + 1 : undefined,
    },
  });
  const { result: overview, query: overviewQuery } = useCustom<PrefillOverview>({
    url: `${apiUrl}/prefill`,
    method: "get",
    queryOptions: { refetchInterval: (q) => (q.state.data?.data?.running ? POLL_MS : false) },
  });
  const running = !!overview?.data?.running;
  // While a run goes, answered rows leave the queue; reload once more when it ends so the last ones go too.
  const wasRunning = useRef(false);
  useEffect(() => {
    if (wasRunning.current && !running) invalidate({ resource: RESOURCE, invalidates: ["all"] });
    wasRunning.current = running;
  }, [running, invalidate]);
  useEffect(() => {
    if (!running) return;
    const timer = setInterval(() => invalidate({ resource: RESOURCE, invalidates: ["all"] }), POLL_MS);
    return () => clearInterval(timer);
  }, [running, invalidate]);
  const pages = result.data?.pages ?? [];
  const rows = pages.flatMap((page) => page.data);
  const total = pages[0]?.total ?? 0;
  const { fetchNextPage, isFetchingNextPage } = listQuery;
  const hasNextPage = !!result.hasNextPage;

  const scrollRef = useRef<HTMLDivElement>(null);
  const sentinelRef = useRef<HTMLTableRowElement>(null);
  useEffect(() => {
    const sentinel = sentinelRef.current;
    if (!sentinel || !hasNextPage || isFetchingNextPage || typeof IntersectionObserver === "undefined") return;
    const observer = new IntersectionObserver((entries) => entries.some((e) => e.isIntersecting) && fetchNextPage(), {
      root: scrollRef.current,
      rootMargin: "200px",
    });
    observer.observe(sentinel);
    return () => observer.disconnect();
  }, [hasNextPage, isFetchingNextPage, rows.length, fetchNextPage]);

  async function remove(id: number) {
    setBusy(true);
    setError(undefined);
    try {
      // Every admin write needs a JSON Content-Type (the backend refuses others).
      await httpClient.delete(`${apiUrl}/${RESOURCE}/${id}`, { data: {}, headers: { "Content-Type": "application/json" } });
      // The rows and the Pending count in the Filter menu read the same resource.
      await invalidate({ resource: RESOURCE, invalidates: ["all"] });
      setConfirming(undefined);
    } catch (e) {
      setError((e as Error).message || "Could not remove it.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <div ref={scrollRef} className="min-h-0 flex-1 overflow-y-auto">
        <table aria-label="Pending" className="w-full border-collapse text-sm">
          <thead className="sticky top-0 z-10 bg-muted">
            <tr>
              {[kind === "word" ? "Word" : "Sentence", "Seen", "From", "Queued", "Status", ""].map((header, i) => (
                <th key={i} scope="col" className="border-b border-border px-4 py-3 text-left text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
                  {header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {listQuery.isLoading && (
              <tr>
                <td colSpan={6} className="p-4 text-muted-foreground">Loading...</td>
              </tr>
            )}
            {listQuery.isError && (
              <tr>
                <td colSpan={6} className="p-4 text-destructive">Could not load the queue.</td>
              </tr>
            )}
            {!listQuery.isLoading && !listQuery.isError && rows.length === 0 && (
              <tr>
                <td colSpan={6} className="p-4 text-muted-foreground">Nothing is waiting for the night job.</td>
              </tr>
            )}
            {rows.map((row) => (
              <tr key={row.id} className="border-b border-border/60">
                <td className="px-4 py-2.5 font-semibold">{row.text}</td>
                <td className="px-4 py-2.5 tabular-nums" title="How many sentences had this word">
                  {row.seenCount}
                </td>
                <td className="px-4 py-2.5 text-muted-foreground">{SOURCES[row.source] ?? row.source}</td>
                <td className="px-4 py-2.5 text-muted-foreground">{row.createdAt.slice(0, 10)}</td>
                <td className="px-4 py-2.5">
                  <Badge variant="default" dot title="Answered by the night job, then it moves to the list">
                    Pending
                  </Badge>
                </td>
                <td className="px-4 py-2.5 text-right">
                  {confirming === row.id ? (
                    <span role="alertdialog" aria-label={`Confirm remove ${row.text}`} className="inline-flex items-center gap-2">
                      <span className="text-xs text-muted-foreground">Remove from the queue?</span>
                      <Button size="icon" variant="destructive" aria-label="Confirm remove" title="Remove" disabled={busy} onClick={() => remove(row.id)}>
                        <Check className="h-4 w-4" />
                      </Button>
                      <Button size="icon" variant="outline" aria-label="Cancel remove" title="Cancel" onClick={() => setConfirming(undefined)}>
                        <X className="h-4 w-4" />
                      </Button>
                    </span>
                  ) : (
                    <Button
                      size="icon"
                      variant="ghost"
                      aria-label={`Remove ${row.text} from the queue`}
                      title="Remove from the queue"
                      onClick={() => setConfirming(row.id)}
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  )}
                </td>
              </tr>
            ))}
            {hasNextPage && (
              <tr ref={sentinelRef} aria-hidden={!isFetchingNextPage}>
                <td colSpan={6} className="p-3 text-center">
                  {isFetchingNextPage && <Loader2 role="status" aria-label="Loading more" className="mx-auto h-4 w-4 animate-spin text-muted-foreground" />}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      {error && (
        <p role="alert" className="border-t border-border px-4 py-2 text-sm text-destructive">
          {error}
        </p>
      )}
      <div aria-label="Night job" className="space-y-1 border-t border-border p-3 text-sm text-muted-foreground">
        <RunNow overview={overview?.data} onStarted={() => overviewQuery.refetch()} />
        <ScheduleNote schedule={overview?.data?.schedule} maxUsdPerRun={overview?.data?.maxUsdPerRun} />
        <p>
          {rows.length.toLocaleString("en-US")} of {total.toLocaleString("en-US")} waiting
        </p>
      </div>
    </>
  );
}
