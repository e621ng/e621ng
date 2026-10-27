import { beforeEach, describe, expect, it, vi } from "vitest";
import { currentPost, flush, hotkeys, loadToolbar, pressHotkey, renderToolbarPage, taskCancelled } from "./fixtures";

vi.mock("@/core/hotkeys", () => ({
  default: { register: (name: string, listener: () => void) => { hotkeys.set(name, listener); } },
}));
vi.mock("@/utility/Page", () => ({ default: { matches: () => true } }));
vi.mock("@/pages/posts/show/notes", () => ({ default: { enabled: false } }));
vi.mock("@/models/Favorite", () => ({ default: { create: vi.fn(), destroy: vi.fn() } }));

const voteSpy = vi.fn();
vi.mock("@/models/PostVote", () => ({ default: { vote: (...args: unknown[]) => voteSpy(...args) } }));

const toast = { track: vi.fn(), dismiss: vi.fn(), notice: vi.fn(), alert: vi.fn() };
vi.mock("@/utility/Toast", () => ({ default: toast }));

function voteResponse (score: number, our_score: number) {
  return { score, up: Math.max(score, 0), down: Math.max(-score, 0), our_score };
}

describe("ToolbarVoting", () => {
  beforeEach(() => {
    voteSpy.mockReset();
    toast.track.mockReset().mockImplementation(
      (promise: Promise<unknown>, _pending: string, done: (result: unknown) => string) => promise.then(done, () => undefined),
    );
    toast.dismiss.mockReset();
    renderToolbarPage();
  });

  describe("buttons", () => {
    it("votes in the direction of the clicked button", async () => {
      voteSpy.mockResolvedValue(voteResponse(1, 1));
      await loadToolbar();

      $(".ptbr-vote-button[data-action='-1']").trigger("click");
      expect(voteSpy).toHaveBeenCalledWith(123, -1, false);
    });

    it("updates the score displays from the response", async () => {
      voteSpy.mockResolvedValue({ score: 3, up: 5, down: 2, our_score: 1 });
      await loadToolbar();

      $(".ptbr-vote-button[data-action='1']").trigger("click");
      await flush();

      expect($(".ptbr-score").text()).toBe("3");
      expect($(".ptbr-breakdown").html()).toBe("<span>5</span><span>2</span>");
      expect($(".ptbr-vote").attr("data-score")).toBe("3");
      expect($(".ptbr-vote").attr("data-up")).toBe("5");
      expect($(".ptbr-vote").attr("data-down")).toBe("2");
      expect($(".ptbr-vote").attr("data-state")).toBe("1");
      expect($(".ptbr-vote").attr("data-vote")).toBe("1");
      expect($(".post-score").text()).toBe("3");
      expect($(".post-score").hasClass("score-positive")).toBe(true);
      expect($(".post-score").hasClass("score-neutral")).toBe(false);
    });

    it("marks a negative score", async () => {
      voteSpy.mockResolvedValue(voteResponse(-2, -1));
      await loadToolbar();

      $(".ptbr-vote-button[data-action='-1']").trigger("click");
      await flush();

      expect($(".ptbr-vote").attr("data-state")).toBe("-1");
      expect($(".post-score").hasClass("score-negative")).toBe(true);
    });

    it("ignores clicks while a vote is pending, then resets", async () => {
      let resolve!: (value: unknown) => void;
      voteSpy.mockReturnValue(new Promise((r) => { resolve = r; }));
      await loadToolbar();

      const up = $(".ptbr-vote-button[data-action='1']");
      const down = $(".ptbr-vote-button[data-action='-1']");
      up.trigger("click");
      up.trigger("click");
      expect(voteSpy).toHaveBeenCalledTimes(1);
      expect(up.attr("processing")).toBe("true");
      expect(down.attr("processing")).toBe("true");
      expect(up.hasClass("anim")).toBe(true);
      expect(down.hasClass("anim")).toBe(false);

      resolve(voteResponse(1, 1));
      await flush();
      expect(up.attr("processing")).toBe("false");
      expect(up.hasClass("anim")).toBe(false);
    });

    it("resets the buttons when the vote fails", async () => {
      voteSpy.mockRejectedValue(new Error("boom"));
      await loadToolbar();

      const up = $(".ptbr-vote-button[data-action='1']");
      up.trigger("click");
      await flush();

      expect(up.attr("processing")).toBe("false");
      expect(up.hasClass("anim")).toBe(false);
      expect($(".ptbr-score").text()).toBe("0");
    });

    it("keeps processing when a vote is superseded, until the replacement lands", async () => {
      await loadToolbar();
      const TaskCancelled = await taskCancelled();

      let resolveSecond!: (value: unknown) => void;
      voteSpy
        .mockReturnValueOnce(Promise.reject(new TaskCancelled("Replaced by a new unique task")))
        .mockReturnValueOnce(new Promise((r) => { resolveSecond = r; }));

      const CurrentPost = await currentPost();
      const up = $(".ptbr-vote-button[data-action='1']");

      // Both calls go through the model; the queue cancels the first
      CurrentPost.vote(1).catch(() => {});
      CurrentPost.vote(1).catch(() => {});
      await flush();
      expect(up.attr("processing")).toBe("true");

      resolveSecond(voteResponse(1, 1));
      await flush();
      expect(up.attr("processing")).toBe("false");
      expect($(".ptbr-score").text()).toBe("1");
    });
  });

  describe("model-driven updates", () => {
    it("re-renders when the vote bypasses the toolbar", async () => {
      voteSpy.mockResolvedValue({ score: 7, up: 8, down: 1, our_score: 1 });
      await loadToolbar();
      const CurrentPost = await currentPost();

      await CurrentPost.voteUp();

      expect(voteSpy).toHaveBeenCalledWith(123, 1, true);
      expect(CurrentPost.stats.score).toEqual({ up: 8, down: 1, total: 7 });
      expect(CurrentPost.stats.vote).toBe(1);
      expect($(".ptbr-score").text()).toBe("7");
      expect($(".ptbr-vote").attr("data-vote")).toBe("1");
      expect($(".ptbr-vote-button").attr("processing")).toBe("false");
    });

    it("renders the initial state from the embedded payload", async () => {
      renderToolbarPage({ score: 4, up: 6, down: 2, vote: -1 });
      await loadToolbar();
      const CurrentPost = await currentPost();

      expect(CurrentPost.stats.score.total).toBe(4);
      expect(CurrentPost.scoreState).toBe(1);
      expect(CurrentPost.stats.vote).toBe(-1);
    });
  });

  describe("hotkeys", () => {
    it.each([
      ["upvote", 1, 1, "Post upvoted."],
      ["upvote", 1, 0, "Upvote removed."],
      ["downvote", -1, -1, "Post downvoted."],
      ["downvote", -1, 0, "Downvote removed."],
    ])("%s with our_score %i reports %s", async (name, direction, ourScore, message) => {
      voteSpy.mockResolvedValue(voteResponse(ourScore, ourScore));
      await loadToolbar();

      pressHotkey(name);
      expect(toast.dismiss).toHaveBeenCalledWith("Post upvoted.", "Post downvoted.");
      expect(voteSpy).toHaveBeenCalledWith(123, direction, false);
      expect(toast.track).toHaveBeenCalledTimes(1);

      const [, pending, done] = toast.track.mock.calls[0];
      expect(pending).toBe("Updating post...");
      expect(done(voteResponse(ourScore, ourScore))).toBe(message);

      await flush();
      expect($(".ptbr-vote").attr("data-vote")).toBe(String(ourScore));
    });

    it("does not leak a rejected vote out of the listener", async () => {
      voteSpy.mockRejectedValue(new Error("boom"));
      await loadToolbar();

      expect(() => pressHotkey("upvote")).not.toThrow();
      await expect(toast.track.mock.results[0].value).resolves.toBeUndefined();
    });
  });

  describe("score breakdown", () => {
    it("toggles the breakdown when the score is clicked", async () => {
      await loadToolbar();
      const breakdown = $(".ptbr-breakdown");

      $(".ptbr-score").trigger("click");
      expect(breakdown.hasClass("hidden")).toBe(false);

      $(".ptbr-score").trigger("click");
      expect(breakdown.hasClass("hidden")).toBe(true);
    });
  });
});
