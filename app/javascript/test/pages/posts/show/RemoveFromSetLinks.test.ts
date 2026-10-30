import { describe, expect, it, vi } from "vitest";

const { removeSpy } = vi.hoisted(() => ({ removeSpy: vi.fn() }));
vi.mock("@/models/PostSet", () => ({ default: { remove_post: removeSpy } }));

describe("RemoveFromSetLinks", () => {
  it("queues a removal with numeric ids from the link's data attributes", async () => {
    document.body.innerHTML = '<a href="#" class="set-nav-remove-link" data-set-id="3" data-post-id="44">x</a>';
    const RemoveFromSetLinks = (await import("@/pages/posts/show/RemoveFromSetLinks")).default;

    void RemoveFromSetLinks.instance;
    const link = document.querySelector<HTMLElement>("a.set-nav-remove-link")!;
    const event = new MouseEvent("click", { bubbles: true, cancelable: true });
    link.dispatchEvent(event);

    expect(removeSpy).toHaveBeenCalledWith(3, 44);
    expect(event.defaultPrevented).toBe(true);
  });
});
