import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const SWF_URL = "/data/ab/cd/abcd1234.swf";

function render ({ player = true } = {}): void {
  const container = `
    <div id="flash-player" class="flash-player" data-swf="${SWF_URL}">
      <canvas class="flash-player-frame" width="640" height="480" aria-hidden="true"></canvas>
      <div class="flash-player-content">
        <button type="button" class="flash-player-start" hidden>Play Flash</button>
        <p class="flash-player-message">Playing Flash files in the browser requires JavaScript.</p>
      </div>
    </div>`;
  document.body.innerHTML = `
    <section id="image-container">
      ${player ? container : ""}
    </section>
    <a href="${SWF_URL}" class="st-button ptbr-fullscreen-button" data-hotkey="fullscreen">Fullscreen</a>`;
}

/** Clicks the toolbar's Fullscreen button; returns whether its default action (opening the file) was prevented. */
function clickFullscreen (): boolean {
  let prevented = false;
  document.addEventListener("click", (event) => {
    prevented = event.defaultPrevented;
    event.preventDefault(); // jsdom cannot navigate
  }, { once: true });
  document.querySelector(".ptbr-fullscreen-button").dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }));
  return prevented;
}

function stubFullscreen ({ supported = true, refuse = false } = {}) {
  let current: Element | null = null;
  Object.defineProperty(document, "fullscreenElement", { configurable: true, get: () => current });
  const exit = vi.fn(() => {
    current = null;
    return Promise.resolve();
  });
  Object.defineProperty(document, "exitFullscreen", { configurable: true, value: exit });
  // Only the player's container ever goes fullscreen in these tests
  const request = vi.fn(() => {
    if (refuse) return Promise.reject(new TypeError("Permissions check failed"));
    current = document.getElementById("flash-player");
    return Promise.resolve();
  });
  Object.defineProperty(HTMLElement.prototype, "requestFullscreen", { configurable: true, value: supported ? request : undefined });
  return { request, exit, element: () => current };
}

async function load () {
  return (await import("@/pages/posts/show/FlashPlayer")).default;
}

async function flush (): Promise<void> {
  for (let i = 0; i < 10; i++) await Promise.resolve();
}

function ruffleScript (): HTMLScriptElement | null {
  return document.head.querySelector<HTMLScriptElement>("script[src$='ruffle.js']");
}

function stubRuffle (load = vi.fn().mockResolvedValue(undefined)) {
  const suspend = vi.fn();
  const player = document.createElement("ruffle-player") as HTMLElement & { ruffle: unknown };
  player.ruffle = vi.fn(() => ({ load, suspend }));
  window.RufflePlayer = { ...window.RufflePlayer, newest: () => ({ createPlayer: () => player as never }) };
  return { player, load, suspend };
}

function message (): string | undefined {
  return document.querySelector("#flash-player .flash-player-message")?.textContent;
}

function expectFallback (): void {
  expect(message()).toContain("could not be started");
  expect(document.querySelector("#flash-player .flash-player-frame")).not.toBeNull();
}

describe("FlashPlayer", () => {
  let fetchMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    vi.resetModules();
    fetchMock = vi.fn().mockResolvedValue({ ok: true, status: 200, arrayBuffer: () => Promise.resolve(new ArrayBuffer(8)) });
    vi.stubGlobal("fetch", fetchMock);
    vi.spyOn(console, "error").mockImplementation(() => {});
  });

  afterEach(() => {
    document.head.querySelectorAll("script").forEach((script) => script.remove());
    delete window.RufflePlayer;
    for (const property of ["fullscreenElement", "exitFullscreen"]) delete (document as never)[property];
    delete (HTMLElement.prototype as never)["requestFullscreen"];
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it("does nothing on pages without a Flash file", async () => {
    render({ player: false });
    expect((await load()).initialize()).toBeNull();
    expect(ruffleScript()).toBeNull();
  });

  it("shows the Play button and loads nothing until it is pressed", async () => {
    render();
    (await load()).initialize();

    expect(document.querySelector<HTMLButtonElement>(".flash-player-start").hidden).toBe(false);
    expect(message()).toBeUndefined();
    expect(fetchMock).not.toHaveBeenCalled();
    expect(ruffleScript()).toBeNull();
  });

  it("fetches the movie, loads Ruffle once and plays it", async () => {
    render();
    (await load()).initialize();
    const button = document.querySelector<HTMLButtonElement>(".flash-player-start");
    button.click();
    button.click();
    await flush();

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(fetchMock).toHaveBeenCalledWith(SWF_URL);
    expect(document.head.querySelectorAll("script[src$='ruffle.js']")).toHaveLength(1);
    expect(ruffleScript().getAttribute("src")).toBe("/ruffle/test/ruffle.js");
    expect(window.RufflePlayer.config).toMatchObject({
      publicPath: "/ruffle/test/",
      polyfills: false,
      openUrlMode: "deny",
      allowScriptAccess: false,
      base: new URL(SWF_URL, document.baseURI).href,
    });

    const { player, load: ruffleLoad } = stubRuffle();
    ruffleScript().onload(new Event("load"));
    await flush();

    expect(document.querySelector("#flash-player .flash-player-content ruffle-player")).toBe(player);
    expect(document.querySelector("#flash-player .flash-player-frame")).not.toBeNull();
    expect(ruffleLoad).toHaveBeenCalledWith({ data: expect.any(ArrayBuffer), swfFileName: "abcd1234.swf" });
  });

  it("suspends a running movie when the post gets blacklisted", async () => {
    render();
    (await load()).initialize();
    document.querySelector<HTMLButtonElement>(".flash-player-start").click();
    const { suspend } = stubRuffle();
    ruffleScript().onload(new Event("load"));
    await flush();

    $("#image-container").trigger("blk:hide");
    expect(suspend).toHaveBeenCalledTimes(1);
  });

  it("falls back when the movie request is blocked", async () => {
    fetchMock.mockRejectedValue(new TypeError("Failed to fetch"));
    render();
    (await load()).initialize();
    document.querySelector<HTMLButtonElement>(".flash-player-start").click();
    await flush();

    expectFallback();
  });

  it("falls back when the movie is missing", async () => {
    fetchMock.mockResolvedValue({ ok: false, status: 404 });
    render();
    (await load()).initialize();
    document.querySelector<HTMLButtonElement>(".flash-player-start").click();
    stubRuffle();
    ruffleScript().onload(new Event("load"));
    await flush();

    expectFallback();
  });

  it("falls back when Ruffle cannot be loaded", async () => {
    render();
    (await load()).initialize();
    document.querySelector<HTMLButtonElement>(".flash-player-start").click();
    ruffleScript().onerror(new Event("error"));
    await flush();

    expectFallback();
    expect(ruffleScript()).toBeNull();
  });

  it("falls back when Ruffle does not start", async () => {
    render();
    (await load()).initialize();
    document.querySelector<HTMLButtonElement>(".flash-player-start").click();
    ruffleScript().onload(new Event("load"));
    await flush();

    expectFallback();
  });

  it("falls back when Ruffle rejects the movie", async () => {
    render();
    (await load()).initialize();
    document.querySelector<HTMLButtonElement>(".flash-player-start").click();
    stubRuffle(vi.fn().mockRejectedValue(new Error("Invalid SWF")));
    ruffleScript().onload(new Event("load"));
    await flush();

    expectFallback();
  });

  describe("toolbar Fullscreen button", () => {
    const container = () => document.getElementById("flash-player");

    it("is left alone on pages without a Flash file", async () => {
      render({ player: false });
      const { request } = stubFullscreen();
      (await load()).initialize();

      expect(clickFullscreen()).toBe(false);
      expect(request).not.toHaveBeenCalled();
    });

    it("goes fullscreen right away, then starts the movie", async () => {
      render();
      const { request, element } = stubFullscreen();
      (await load()).initialize();

      expect(clickFullscreen()).toBe(true);
      // Synchronously, while the click still counts as a user action
      expect(request).toHaveBeenCalledTimes(1);
      expect(request.mock.contexts[0]).toBe(container());
      expect(fetchMock).toHaveBeenCalledWith(SWF_URL);

      const { load: ruffleLoad } = stubRuffle();
      ruffleScript().onload(new Event("load"));
      await flush();
      expect(ruffleLoad).toHaveBeenCalledTimes(1);
      expect(element()).toBe(container());
    });

    it("only goes fullscreen when the movie is already playing", async () => {
      render();
      const { request } = stubFullscreen();
      (await load()).initialize();
      document.querySelector<HTMLButtonElement>(".flash-player-start").click();
      const { player } = stubRuffle();
      ruffleScript().onload(new Event("load"));
      await flush();

      clickFullscreen();
      await flush();
      expect(request).toHaveBeenCalledTimes(1);
      expect(fetchMock).toHaveBeenCalledTimes(1);
      expect(document.querySelector("#flash-player ruffle-player")).toBe(player);
    });

    it("does nothing while the post is blacklisted", async () => {
      render();
      document.getElementById("image-container").classList.add("blacklisted");
      const { request } = stubFullscreen();
      (await load()).initialize();

      expect(clickFullscreen()).toBe(true); // The file is not opened either
      expect(request).not.toHaveBeenCalled();
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it("plays inline where fullscreen is not supported", async () => {
      render();
      stubFullscreen({ supported: false });
      (await load()).initialize();

      clickFullscreen();
      const { load: ruffleLoad } = stubRuffle();
      ruffleScript().onload(new Event("load"));
      await flush();
      expect(ruffleLoad).toHaveBeenCalledTimes(1);
    });

    it("plays inline when fullscreen is refused", async () => {
      const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
      render();
      const { element } = stubFullscreen({ refuse: true });
      (await load()).initialize();

      clickFullscreen();
      const { load: ruffleLoad } = stubRuffle();
      ruffleScript().onload(new Event("load"));
      await flush();
      expect(ruffleLoad).toHaveBeenCalledTimes(1);
      expect(element()).toBeNull();
      expect(warn).toHaveBeenCalledWith("Flash player: fullscreen refused", expect.any(TypeError));
    });

    it("suspends the movie and leaves fullscreen when the post gets blacklisted", async () => {
      render();
      const { exit, element } = stubFullscreen();
      (await load()).initialize();
      clickFullscreen();
      const { suspend } = stubRuffle();
      ruffleScript().onload(new Event("load"));
      await flush();

      $("#image-container").trigger("blk:hide");
      expect(suspend).toHaveBeenCalledTimes(1);
      expect(exit).toHaveBeenCalledTimes(1);
      expect(element()).toBeNull();
    });

    it("leaves fullscreen when the movie fails to start, and can try again", async () => {
      fetchMock.mockResolvedValueOnce({ ok: false, status: 404 });
      render();
      const { exit, element } = stubFullscreen();
      (await load()).initialize();

      clickFullscreen();
      await flush();
      expect(exit).toHaveBeenCalledTimes(1);
      expect(element()).toBeNull();
      expectFallback();

      document.querySelector<HTMLButtonElement>(".flash-player-retry").click();
      expect(fetchMock).toHaveBeenCalledTimes(2);
      const { load: ruffleLoad } = stubRuffle();
      ruffleScript().onload(new Event("load"));
      await flush();
      expect(ruffleLoad).toHaveBeenCalledTimes(1);
    });
  });
});
