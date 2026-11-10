import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { jsonResponse } from "../../helpers";

const noticeSpy = vi.fn();
const alertSpy = vi.fn();
vi.mock("@/utility/Toast", () => ({
  default: { notice: (msg: string) => noticeSpy(msg), alert: (msg: string) => alertSpy(msg), create: vi.fn() },
}));

const loadPostData = vi.fn();
const renderDTextThumbnails = vi.fn();
vi.mock("@/core/DeferredPostLoader", () => ({
  default: { loadPostData: (...args: unknown[]) => loadPostData(...args), renderDTextThumbnails: () => renderDTextThumbnails() },
}));

function pollHTML (opts: { selected?: number[]; maxChoices?: number; multiple?: boolean; withClear?: boolean } = {}): string {
  const selected = opts.selected ?? [];
  const type = opts.multiple ? "checkbox" : "radio";
  let clear = "";
  if (opts.withClear)
    clear = `<form class="forum-poll-clear-form" action="/forum_topics/7/poll/vote" method="post">
        <input type="hidden" name="_method" value="delete"><button type="submit">Clear vote</button></form>`;
  const option = (id: number) => `
    <li class="forum-poll-option" data-option-id="${id}" data-selected="${selected.includes(id)}">
      <input type="${type}" name="option_ids[]" value="${id}" ${selected.includes(id) ? "checked" : ""}>
    </li>`;
  return `
    <section class="forum-poll" id="forum-poll" data-topic-id="7" data-max-choices="${opts.maxChoices ?? 1}" data-state="ready">
      <form class="forum-poll-ballot" action="/forum_topics/7/poll/vote" method="post">
        <input type="hidden" name="_method" value="put">
        <input type="hidden" name="authenticity_token" value="tok">
        <ol>${option(1)}${option(2)}${option(3)}</ol>
        <input type="submit" value="Vote">
      </form>
      ${clear}
    </section>`;
}

function render (opts: Parameters<typeof pollHTML>[0] = {}): void {
  document.body.innerHTML = `<div id="forum-poll-container">${pollHTML(opts)}</div>`;
}

async function load (): Promise<void> {
  const { default: PollVote } = await import("@/pages/forum_topics/PollVote");
  void PollVote.instance;
}

function submit (selector: string): void {
  const form = document.querySelector(selector) as HTMLFormElement;
  form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
}

const settle = () => vi.waitFor(() => expect(document.querySelector("#forum-poll")?.getAttribute("data-state")).toBe("ready"));

describe("PollVote", () => {
  beforeEach(() => {
    noticeSpy.mockReset();
    alertSpy.mockReset();
    loadPostData.mockReset();
    renderDTextThumbnails.mockReset();
  });

  afterEach(() => {
    vi.restoreAllMocks();
    document.body.innerHTML = "";
  });

  it("submits the ballot as a JSON PUT and swaps in the returned HTML", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({
      option_ids: [2], html: pollHTML({ selected: [2], withClear: true }), posts: { 5: { id: 5 } },
    }));
    render();
    await load();
    (document.querySelector("input[value='2']") as HTMLInputElement).checked = true;

    submit("form.forum-poll-ballot");
    await settle();

    expect(fetchSpy).toHaveBeenCalledTimes(1);
    const [url, init] = fetchSpy.mock.calls[0] as [string, RequestInit];
    expect(url).toBe("/forum_topics/7/poll/vote.json");
    expect(init.method).toBe("PUT");
    const body = init.body as FormData;
    expect(body.getAll("option_ids[]")).toEqual(["2"]);
    expect(body.has("_method")).toBe(false);
    expect(body.has("authenticity_token")).toBe(false);

    expect(document.querySelector("li[data-option-id='2']")?.getAttribute("data-selected")).toBe("true");
    expect(document.querySelector("form.forum-poll-clear-form")).not.toBeNull();
    expect(loadPostData).toHaveBeenCalledWith({ 5: { id: 5 } });
    expect(renderDTextThumbnails).toHaveBeenCalledTimes(1);
    expect(noticeSpy).toHaveBeenCalledWith("Vote saved");
  });

  it("keeps working after the swap because events are delegated", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch")
      .mockResolvedValueOnce(jsonResponse({ option_ids: [1], html: pollHTML({ selected: [1], withClear: true }), posts: {} }))
      .mockResolvedValueOnce(jsonResponse({ option_ids: [], html: pollHTML(), posts: {} }));
    render();
    await load();
    (document.querySelector("input[value='1']") as HTMLInputElement).checked = true;
    submit("form.forum-poll-ballot");
    await settle();

    submit("form.forum-poll-clear-form");
    await settle();

    expect(fetchSpy).toHaveBeenCalledTimes(2);
    expect((fetchSpy.mock.calls[1][1] as RequestInit).method).toBe("DELETE");
    expect(document.querySelector("form.forum-poll-clear-form")).toBeNull();
    expect(noticeSpy).toHaveBeenLastCalledWith("Vote cleared");
  });

  it("refuses an empty ballot without a request", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    render();
    await load();
    submit("form.forum-poll-ballot");
    expect(fetchSpy).not.toHaveBeenCalled();
    expect(alertSpy).toHaveBeenCalledWith("Select at least one option.");
  });

  it("shows the server error message", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(jsonResponse({ success: false, message: "This poll has closed" }, { status: 422 }));
    render();
    await load();
    (document.querySelector("input[value='3']") as HTMLInputElement).checked = true;
    submit("form.forum-poll-ballot");
    await settle();
    expect(alertSpy).toHaveBeenCalledWith("This poll has closed");
    expect(document.querySelectorAll("li.forum-poll-option")).toHaveLength(3);
  });

  it("greys out unchecked boxes once max_choices is reached", async () => {
    render({ multiple: true, maxChoices: 2, selected: [1] });
    await load();
    const boxes = Array.from(document.querySelectorAll<HTMLInputElement>("input[type='checkbox']"));
    expect(boxes.map((b) => b.disabled)).toEqual([false, false, false]);

    boxes[1].checked = true;
    boxes[1].dispatchEvent(new Event("change", { bubbles: true }));
    expect(boxes.map((b) => b.disabled)).toEqual([false, false, true]);

    boxes[1].checked = false;
    boxes[1].dispatchEvent(new Event("change", { bubbles: true }));
    expect(boxes.map((b) => b.disabled)).toEqual([false, false, false]);
  });

  it("boots without a poll on the page", async () => {
    document.body.innerHTML = "<div id='c-forum-topics'></div>";
    await expect(load()).resolves.toBeUndefined();
  });
});
