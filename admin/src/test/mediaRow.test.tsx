import { Refine, type DataProvider } from "@refinedev/core";
import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { MediaSearchResult, WordItem } from "@/api/types";
import { MediaRow } from "@/components/MediaRow";
import { httpClient } from "@/providers/dataProvider";

const API = "https://api.test/api/admin";

const word: WordItem = {
  id: "b-5",
  word: "run",
  needsReview: false,
  source: "bundled",
  model: "haiku",
  promptVersion: "v3",
  createdAt: "2026-10-14T10:00:00Z",
  entry: { senses: [] },
  media: [{ url: "https://api.saynata.com/media/run_1_ab.webp", kind: "photo", photographer: "Jane Photo", pageUrl: "https://pixabay.com/photos/x-1/" }],
  mediaStatus: [null],
};

function result(id: number, kind: "photo" | "clip" = "photo"): MediaSearchResult {
  return {
    kind,
    pixabayId: id,
    previewUrl: `https://cdn.pixabay.com/preview/${id}.jpg`,
    downloadUrl: `https://cdn.pixabay.com/x/${id}`,
    photographer: `Person ${id}`,
    pageUrl: `https://pixabay.com/x-${id}/`,
  };
}

function renderRow(item: WordItem = word) {
  const dataProvider = { getList: vi.fn(), getApiUrl: () => API } as unknown as DataProvider;
  render(
    <MemoryRouter>
      <Refine dataProvider={dataProvider} options={{ disableTelemetry: true }}>
        <MediaRow word={item} index={0} />
      </Refine>
    </MemoryRouter>,
  );
}

describe("media row", () => {
  const get = vi.spyOn(httpClient, "get");
  const put = vi.spyOn(httpClient, "put");
  const del = vi.spyOn(httpClient, "delete");
  const post = vi.spyOn(httpClient, "post");

  beforeEach(() => {
    get.mockResolvedValue({ data: { query: "person running", results: [result(1), result(2, "clip"), result(3)] } });
    put.mockResolvedValue({ data: {} });
    del.mockResolvedValue({ data: {} });
    post.mockResolvedValue({ data: {} });
  });
  afterEach(() => vi.clearAllMocks());

  it("shows the current photo with its credit and icon-only buttons and no Pixabay search", () => {
    renderRow();
    expect(screen.getByRole("img", { name: "run, sense 1" })).toHaveAttribute("src", "https://api.saynata.com/media/run_1_ab.webp");
    expect(screen.getByRole("link", { name: "Jane Photo" })).toBeInTheDocument();
    for (const name of ["No image", "Draw an AI picture"]) {
      const button = screen.getByRole("button", { name });
      // Icon only (CLAUDE.md): the button has no visible text.
      expect(button).toHaveTextContent("");
      expect(button.querySelector("svg")).not.toBeNull();
    }
    expect(screen.queryByRole("button", { name: "Pick another image" })).not.toBeInTheDocument();
  });


  it("No image sends DELETE for the sense", async () => {
    renderRow();
    await userEvent.click(screen.getByRole("button", { name: "No image" }));
    await vi.waitFor(() => expect(del).toHaveBeenCalledTimes(1));
    expect(del.mock.calls[0][0]).toBe(`${API}/words/b-5/senses/0/media`);
  });

  it("the Sparkles button opens the AI picture dialog and sends nothing (TASK-91)", async () => {
    get.mockResolvedValue({ data: { prompt: "A prompt", source: "template", usage: { picturesToday: 0, picturesPerDay: 30, sceneUsdToday: 0, sceneUsdPerDay: 1 } } });
    renderRow();
    await userEvent.click(screen.getByRole("button", { name: "Draw an AI picture" }));
    expect(await screen.findByRole("dialog")).toBeInTheDocument();
    expect(post).not.toHaveBeenCalled();
  });

  it("shows that a sense is waiting for an AI image, and the button still opens the dialog", () => {
    renderRow({ ...word, mediaStatus: ["needs_ai"] });
    expect(screen.getByText("Waiting for an AI image")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Draw an AI picture" })).toBeEnabled();
  });

  it("shows the message of the backend when a change fails", async () => {
    del.mockRejectedValue({ response: { data: { detail: "Could not remove that picture." } } });
    renderRow();
    await userEvent.click(screen.getByRole("button", { name: "No image" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("Could not remove that picture.");
  });
});

describe("full-size viewer (TASK-77)", () => {
  const get = vi.spyOn(httpClient, "get");
  beforeEach(() => {
    get.mockResolvedValue({ data: { query: "person running", results: [result(1), result(2, "clip"), result(3)] } });
  });
  afterEach(() => vi.clearAllMocks());

  it("opens from the photo in the Media row with the right source and caption", async () => {
    renderRow();
    await userEvent.click(screen.getByRole("button", { name: "View run, sense 1 full size" }));

    const dialog = await screen.findByRole("dialog");
    expect(within(dialog).getByRole("img", { name: "run · sense 1" })).toHaveAttribute("src", "https://api.saynata.com/media/run_1_ab.webp");
    expect(dialog).toHaveTextContent("run · sense 1 · Photo by Jane Photo on Pixabay");
    expect(within(dialog).getByRole("link", { name: "Jane Photo" })).toHaveAttribute("href", "https://pixabay.com/photos/x-1/");
    expect(within(dialog).getByRole("button", { name: "Close" })).toHaveTextContent("");
  });

  it("plays a clip with controls, muted until the viewer unmutes", async () => {
    renderRow({ ...word, media: [{ url: "https://api.saynata.com/media/run_1_ab.mp4", kind: "clip", photographer: "Pat Maker", pageUrl: "https://pixabay.com/videos/x-2/" }] });
    await userEvent.click(screen.getByRole("button", { name: "View run, sense 1 full size" }));

    const dialog = await screen.findByRole("dialog");
    const video = within(dialog).getByLabelText("run · sense 1") as HTMLVideoElement;
    expect(video.tagName).toBe("VIDEO");
    expect(video).toHaveAttribute("src", "https://api.saynata.com/media/run_1_ab.mp4");
    expect(video.controls).toBe(true);
    expect(video.muted).toBe(true);
    expect(dialog).toHaveTextContent("run · sense 1 · Clip by Pat Maker on Pixabay");
  });

  it("closes with Esc and gives the focus back to the clicked media", async () => {
    renderRow();
    const opener = screen.getByRole("button", { name: "View run, sense 1 full size" });
    await userEvent.click(opener);
    await screen.findByRole("dialog");

    await userEvent.keyboard("{Escape}");

    await vi.waitFor(() => expect(screen.queryByRole("dialog")).not.toBeInTheDocument());
    await vi.waitFor(() => expect(opener).toHaveFocus());
  });

  it("closes with the Close button", async () => {
    renderRow();
    await userEvent.click(screen.getByRole("button", { name: "View run, sense 1 full size" }));
    await userEvent.click(await screen.findByRole("button", { name: "Close" }));
    await vi.waitFor(() => expect(screen.queryByRole("dialog")).not.toBeInTheDocument());
  });

  it("closes with a click on the dark backdrop", async () => {
    renderRow();
    await userEvent.click(screen.getByRole("button", { name: "View run, sense 1 full size" }));
    await screen.findByRole("dialog");

    await userEvent.click(screen.getByTestId("lightbox-backdrop"));

    await vi.waitFor(() => expect(screen.queryByRole("dialog")).not.toBeInTheDocument());
  });
});

describe("picture review (TASK-80)", () => {
  const post = vi.spyOn(httpClient, "post");
  const del = vi.spyOn(httpClient, "delete");

  beforeEach(() => {
    post.mockResolvedValue({ data: {} });
    del.mockResolvedValue({ data: {} });
  });
  afterEach(() => vi.clearAllMocks());

  it("approves the picture with the check button and reads the list again", async () => {
    renderRow({ ...word, mediaReview: [{ state: "to_review" }] });
    const button = screen.getByRole("button", { name: "Picture looks right" });
    expect(button).toHaveAttribute("aria-pressed", "false");
    expect(screen.queryByText("Approved")).not.toBeInTheDocument();

    await userEvent.click(button);

    await vi.waitFor(() => expect(post).toHaveBeenCalledWith(`${API}/words/b-5/senses/0/media/approve`, {}, expect.anything()));
    expect(del).not.toHaveBeenCalled();
  });

  it("shows Approved, and the same button undoes the approval", async () => {
    renderRow({ ...word, mediaReview: [{ state: "approved" }] });
    expect(screen.getByText("Approved")).toBeInTheDocument();
    const button = screen.getByRole("button", { name: "Picture looks right" });
    expect(button).toHaveAttribute("aria-pressed", "true");

    await userEvent.click(button);

    await vi.waitFor(() => expect(del).toHaveBeenCalledWith(`${API}/words/b-5/senses/0/media/approve`, expect.anything()));
    expect(post).not.toHaveBeenCalled();
  });

  it("shows Claude's verdict and reason under the media, and nothing when there is none", async () => {
    renderRow({ ...word, mediaReview: [{ state: "wrong", verdict: "wrong", reason: "the picture shows a toy phone, not a food can" }] });
    expect(screen.getByText(/Claude: wrong/)).toHaveTextContent("Claude: wrong \u2014 the picture shows a toy phone, not a food can");
  });

  it("has no verdict line and no approve button for a sense without media", async () => {
    renderRow({ ...word, media: [null], mediaReview: [{ state: "none" }] });
    expect(screen.queryByText(/Claude:/)).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Picture looks right" })).not.toBeInTheDocument();
  });
});
