import { beforeEach, describe, expect, it, vi } from "vitest";
import { setSiteData } from "../../../helpers";

const post = { undelete: vi.fn(), expunge: vi.fn(), regenerateImageSamples: vi.fn(), regenerateVideoSamples: vi.fn(), copyNotes: vi.fn() };
const approval = { create: vi.fn(), destroy: vi.fn(), disapprove: vi.fn() };
const flag = { create: vi.fn(), destroy: vi.fn() };
const user = { setAvatar: vi.fn() };
const toast = { notice: vi.fn(), alert: vi.fn() };

vi.mock("@/models/Post", async (importOriginal) => ({ ...await importOriginal<object>(), default: post }));
vi.mock("@/models/PostApproval", () => ({ default: approval }));
vi.mock("@/models/PostFlag", () => ({ default: flag }));
vi.mock("@/models/CurrentUser", () => ({ default: user }));
vi.mock("@/utility/Toast", () => ({ default: toast }));

const POST_ID = 123;

function render (size = 1024) {
  $("body").append(`
    <section id="image-container" data-size="${size}"></section>
    <a class="undelete-post-link" href="#" data-pid="${POST_ID}">Undelete</a>
    <a class="approve-post-link" href="#" data-pid="${POST_ID}">Approve</a>
    <a class="approve-post-and-navigate-link" href="#" data-pid="${POST_ID}" data-location="/staff/post/queues/next">Approve and next</a>
    <a id="unapprove-post-link" href="#" data-pid="${POST_ID}">Unapprove</a>
    <a class="disapprove-post-link" href="#" data-pid="${POST_ID}" data-reason="borderline_quality">Borderline</a>
    <a class="unflag-post-link" href="#" data-pid="${POST_ID}" data-type="approve">Unflag+approve</a>
    <a class="unflag-post-link plain" href="#" data-pid="${POST_ID}">Unflag</a>
    <a class="move-flag-to-parent-link" href="#" data-pid="${POST_ID}" data-parent-id="99" data-reason-name="inferior" data-note="n">Move</a>
    <a id="destroy-post-link" href="#" data-pid="${POST_ID}">Destroy</a>
    <a id="regenerate-image-samples-link" href="#" data-pid="${POST_ID}">Regen</a>
    <a id="regenerate-video-samples-link" href="#" data-pid="${POST_ID}">Regen video</a>
    <a id="set-as-avatar-link" href="#" data-post-id="${POST_ID}">Avatar</a>
    <a id="copy-notes" href="#">Copy notes</a>
  `);
}

async function load () {
  setSiteData("post-data", { id: POST_ID });
  const PostActions = (await import("@/pages/posts/show/PostActions")).default;
  const reload = vi.spyOn(PostActions as any, "reload").mockImplementation(() => {});
  const navigate = vi.spyOn(PostActions as any, "navigate").mockImplementation(() => {});
  void PostActions.instance;
  return { reload, navigate };
}

async function click (selector: string) {
  const event = $.Event("click");
  $(selector).trigger(event);
  for (let i = 0; i < 5; i++) await Promise.resolve();
  return event;
}

describe("PostActions", () => {
  beforeEach(() => {
    for (const group of [post, approval, flag, user, toast])
      for (const fn of Object.values(group)) fn.mockReset().mockResolvedValue(undefined);
    vi.spyOn(window, "confirm").mockReturnValue(true);
    vi.spyOn(window, "prompt").mockReturnValue(null);
  });

  it("undeletes after confirmation and reloads", async () => {
    render();
    const { reload } = await load();

    const event = await click(".undelete-post-link");

    expect(event.isDefaultPrevented()).toBe(true);
    expect(window.confirm).toHaveBeenCalledWith("Are you sure you want to undelete this post?");
    expect(post.undelete).toHaveBeenCalledWith(POST_ID);
    expect(toast.notice).toHaveBeenCalledWith("Undeleted post.");
    expect(reload).toHaveBeenCalledOnce();
  });

  it("does not undelete when the confirmation is declined", async () => {
    render();
    vi.mocked(window.confirm).mockReturnValue(false);
    const { reload } = await load();

    await click(".undelete-post-link");

    expect(post.undelete).not.toHaveBeenCalled();
    expect(reload).not.toHaveBeenCalled();
  });

  it("approves and reloads, or navigates onwards", async () => {
    render();
    const { reload, navigate } = await load();

    await click(".approve-post-link");
    expect(approval.create).toHaveBeenCalledWith(POST_ID);
    expect(reload).toHaveBeenCalledOnce();

    await click(".approve-post-and-navigate-link");
    expect(approval.create).toHaveBeenCalledTimes(2);
    expect(navigate).toHaveBeenCalledWith("/staff/post/queues/next");
  });

  it("unapproves, disapproves and unflags with a reload", async () => {
    render();
    const { reload } = await load();

    await click("#unapprove-post-link");
    expect(approval.destroy).toHaveBeenCalledWith(POST_ID);
    expect(toast.notice).toHaveBeenCalledWith("Unapproved post.");

    await click(".disapprove-post-link");
    expect(approval.disapprove).toHaveBeenCalledWith(POST_ID, "borderline_quality");

    await click(".unflag-post-link:not(.plain)");
    expect(flag.destroy).toHaveBeenCalledWith(POST_ID, "approve");
    expect(toast.notice).toHaveBeenCalledWith("Unflagged post");

    await click(".unflag-post-link.plain");
    expect(flag.destroy).toHaveBeenLastCalledWith(POST_ID, "none");

    expect(reload).toHaveBeenCalledTimes(4);
  });

  it("moves a flag to the parent in order, then opens the parent's deletion page", async () => {
    render();
    const { navigate } = await load();

    await click(".move-flag-to-parent-link");

    expect(window.confirm).toHaveBeenCalledWith("Move flag to parent?");
    expect(flag.destroy).toHaveBeenCalledWith(POST_ID, "none");
    expect(flag.create).toHaveBeenCalledWith(99, { reason_name: "inferior", parent_id: POST_ID, note: "n" });
    expect(flag.destroy.mock.invocationCallOrder[0]).toBeLessThan(flag.create.mock.invocationCallOrder[0]);
    expect(navigate).toHaveBeenCalledWith("/staff/post/posts/99/confirm_delete");
  });

  it("does not flag the parent when unflagging fails", async () => {
    render();
    flag.destroy.mockRejectedValue(new Error("nope"));
    const { navigate } = await load();

    await click(".move-flag-to-parent-link");

    expect(flag.create).not.toHaveBeenCalled();
    expect(navigate).not.toHaveBeenCalled();
  });

  it("destroys with the prompted reason", async () => {
    render();
    vi.mocked(window.prompt).mockReturnValue("dupe");
    const { navigate } = await load();

    await click("#destroy-post-link");

    expect(post.expunge).toHaveBeenCalledWith(POST_ID, "dupe");
    expect(navigate).toHaveBeenCalledWith(`/staff/destroyed_posts/${POST_ID}`);
  });

  it("does not destroy when the prompt is cancelled", async () => {
    render();
    await load();

    await click("#destroy-post-link");

    expect(post.expunge).not.toHaveBeenCalled();
  });

  it("regenerates samples with a size-dependent notice", async () => {
    render(5 * 1024 * 1024);
    await load();

    await click("#regenerate-image-samples-link");
    expect(post.regenerateImageSamples).toHaveBeenCalledWith(POST_ID);
    expect(toast.notice).toHaveBeenLastCalledWith("Image samples regenerated successfully.");

    $("#image-container").data("size", 11 * 1024 * 1024);
    await click("#regenerate-image-samples-link");
    expect(toast.notice).toHaveBeenLastCalledWith("Large file: Image samples will be regenerated soon.");

    await click("#regenerate-video-samples-link");
    expect(post.regenerateVideoSamples).toHaveBeenCalledWith(POST_ID);
    expect(toast.notice).toHaveBeenLastCalledWith("Video samples will be regenerated in a few minutes.");
  });

  it("sets the avatar after confirmation", async () => {
    render();
    await load();

    await click("#set-as-avatar-link");

    expect(window.confirm).toHaveBeenCalledWith("Set post as avatar?");
    expect(user.setAvatar).toHaveBeenCalledWith(POST_ID);
    expect(toast.notice).toHaveBeenCalledWith("Post set as avatar. You can crop it further <a href='/maintenance/user/avatar/edit'>here</a>.");
  });

  it("copies notes to the prompted post", async () => {
    render();
    vi.mocked(window.prompt).mockReturnValue("456");
    await load();

    await click("#copy-notes");

    expect(post.copyNotes).toHaveBeenCalledWith(POST_ID, 456);
    expect(toast.notice).toHaveBeenCalledWith("Successfully copied notes to <a href='456'>post #456</a>");
  });

  it("ignores a cancelled or non-numeric copy-notes prompt", async () => {
    render();
    await load();

    await click("#copy-notes");
    vi.mocked(window.prompt).mockReturnValue("abc");
    await click("#copy-notes");

    expect(post.copyNotes).not.toHaveBeenCalled();
  });

  it("stays quiet when a request fails, since the model already reported it", async () => {
    render();
    post.undelete.mockRejectedValue(new Error("nope"));
    const { reload } = await load();

    await click(".undelete-post-link");

    expect(toast.notice).not.toHaveBeenCalled();
    expect(reload).not.toHaveBeenCalled();
  });
});
