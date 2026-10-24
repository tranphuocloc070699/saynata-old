import { Refine, type DataProvider } from "@refinedev/core";
import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { PrefillQueueItem, PrefillSchedule, WordItem } from "@/api/types";
import { nextRunText } from "@/components/PendingQueue";
import { WordsPage } from "@/pages/WordsPage";
import { httpClient } from "@/providers/dataProvider";

const API = "https://api.test/api/admin";

const house: WordItem = {
  id: 2,
  word: "house",
  needsReview: false,
  source: "bundled",
  model: "haiku",
  promptVersion: "v3",
  createdAt: "2026-10-14T10:00:00Z",
  entry: { senses: [{ pos: "noun", cefr: "A1", simpleDefinition: "A home.", vietnamese: "ngôi nhà", examples: [], usage: [] }] },
};

const lantern: PrefillQueueItem = {
  id: 7,
  kind: "word",
  text: "lantern",
  targetLang: "",
  source: "sentence-words",
  seenCount: 3,
  priority: 400,
  status: "pending",
  attempts: 0,
  createdAt: "2026-10-23T02:00:00Z",
  updatedAt: "2026-10-23T02:00:00Z",
};

afterEach(() => vi.restoreAllMocks());

function renderWords(schedule: PrefillSchedule = { on: true, cron: "0 0 20 * * *", nextRunAt: "2999-01-01T20:00:00Z", sources: ["sentence-words"] }) {
  let queue = [lantern];
  const getList = vi.fn().mockImplementation(async ({ resource, filters }) => {
    if (resource === "prefill/items") return { data: queue, total: queue.length };
    const needsReview = filters?.some((f: { field: string }) => f.field === "needs_review");
    const data = needsReview ? [] : [house];
    return { data, total: data.length };
  });
  const del = vi.spyOn(httpClient, "delete").mockImplementation(async () => {
    queue = [];
    return { data: { ...lantern, status: "skipped" } };
  });
  const custom = vi.fn().mockImplementation(async () => ({ data: { running: false, maxUsdPerRun: 0.5, spentTodayUsd: 0, schedule } }));
  const dataProvider = { getList, custom, getApiUrl: () => API } as unknown as DataProvider;
  render(
    <MemoryRouter>
      <Refine dataProvider={dataProvider} options={{ disableTelemetry: true }}>
        <WordsPage />
      </Refine>
    </MemoryRouter>,
  );
  return { getList, del };
}

async function choose(label: string) {
  if (!screen.queryByRole("group", { name: "Filter choices" })) {
    await userEvent.click(screen.getByRole("button", { name: /^Filter/ }));
  }
  await userEvent.click(within(screen.getByRole("group", { name: "Filter choices" })).getByRole("button", { name: label }));
}

describe("Pending (TASK-101)", () => {
  it("shows the pending count in the menu and the queue rows of this kind when chosen", async () => {
    const { getList } = renderWords();
    await screen.findByText("house");
    await userEvent.click(screen.getByRole("button", { name: /^Filter/ }));
    await vi.waitFor(() => expect(screen.getByRole("button", { name: "Pending" })).toHaveTextContent(/1$/));

    await choose("Pending");

    const table = await screen.findByRole("table", { name: "Pending" });
    const row = (await within(table).findByText("lantern")).closest("tr")!;
    expect(within(row).getByText("3")).toBeInTheDocument();
    expect(within(row).getByText("In a sentence")).toBeInTheDocument();
    expect(within(row).getByText("Pending")).toBeInTheDocument();
    expect(screen.queryByRole("table", { name: "Rows" })).not.toBeInTheDocument();
    const queueCall = getList.mock.calls.find((c) => c[0].resource === "prefill/items" && c[0].pagination?.pageSize === 50);
    expect(queueCall![0].filters).toEqual([
      { field: "kind", operator: "eq", value: "word" },
      { field: "status", operator: "eq", value: "pending" },
    ]);
  });

  it("is on alone: Pending turns the other choices off, and another choice turns Pending off", async () => {
    renderWords();
    await screen.findByText("house");
    await choose("Bundled");
    await choose("Pending");
    expect(screen.getByRole("button", { name: "Bundled" })).toHaveAttribute("aria-pressed", "false");
    expect(await screen.findByRole("table", { name: "Pending" })).toBeInTheDocument();

    await choose("Needs review");
    expect(screen.getByRole("button", { name: "Pending" })).toHaveAttribute("aria-pressed", "false");
    expect(await screen.findByRole("table", { name: "Rows" })).toBeInTheDocument();
  });

  it("removes a row after asking, then reloads the rows and the count", async () => {
    const { del } = renderWords();
    await screen.findByText("house");
    await choose("Pending");
    const table = await screen.findByRole("table", { name: "Pending" });
    await within(table).findByText("lantern");

    await userEvent.click(screen.getByRole("button", { name: "Remove lantern from the queue" }));
    // Cancel changes nothing.
    await userEvent.click(screen.getByRole("button", { name: "Cancel remove" }));
    expect(del).not.toHaveBeenCalled();

    await userEvent.click(screen.getByRole("button", { name: "Remove lantern from the queue" }));
    await userEvent.click(screen.getByRole("button", { name: "Confirm remove" }));

    await vi.waitFor(() => expect(del).toHaveBeenCalledTimes(1));
    expect(del.mock.calls[0][0]).toBe(`${API}/prefill/items/7`);
    expect(del.mock.calls[0][1]).toMatchObject({ headers: { "Content-Type": "application/json" } });
    expect(await screen.findByText("Nothing is waiting for the night job.")).toBeInTheDocument();
    // The menu closed when the row was clicked; open it again to read the count.
    await userEvent.click(screen.getByRole("button", { name: /^Filter/ }));
    await vi.waitFor(() => expect(screen.getByRole("button", { name: "Pending" })).toHaveTextContent(/0$/));
  });

  it("says when the night job runs next, its cap, and that it answers only one source", async () => {
    renderWords();
    await screen.findByText("house");
    await choose("Pending");
    const note = await screen.findByLabelText("Night job");
    await within(note).findByText(/Next night run: 2999-01-01 20:00 UTC \(03:00 Vietnam\)/);
    expect(note).toHaveTextContent("cap $0.50");
    expect(note).toHaveTextContent('The night run answers only "In a sentence" items. Other sources wait until you run them by hand.');
  });

  it("says the night job is off when the cron is empty", async () => {
    renderWords({ on: false, cron: "", sources: ["sentence-words"] });
    await screen.findByText("house");
    await choose("Pending");
    const note = await screen.findByLabelText("Night job");
    await within(note).findByText(/The night job is off \(PREFILL_CRON is empty\)/);
  });
});

describe("nextRunText", () => {
  const now = new Date("2026-10-25T17:00:00Z");
  it("says today with the hours left", () => {
    expect(nextRunText("2026-10-25T20:00:00Z", now)).toBe("today 20:00 UTC (03:00 Vietnam), in 3 h");
  });
  it("says tomorrow, and minutes when under an hour", () => {
    expect(nextRunText("2026-10-26T20:00:00Z", now)).toMatch(/^tomorrow 20:00 UTC \(03:00 Vietnam\), in 27 h$/);
    expect(nextRunText("2026-10-25T17:40:00Z", now)).toBe("today 17:40 UTC (00:40 Vietnam), in 40 min");
  });
});
