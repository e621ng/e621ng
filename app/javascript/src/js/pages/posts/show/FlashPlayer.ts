/// <reference types="vite/client" />

// Plays .swf posts with Ruffle (https://ruffle.rs), a Flash emulator. Ruffle is self-hosted: vite.config.mts emits
// its files under a versioned directory next to the bundles. Nothing is downloaded until the user presses Play,
// neither the movie nor Ruffle itself (its wasm alone is about 14 MB).

declare const __RUFFLE_ASSET_DIR__: string;

interface RufflePlayerElement extends HTMLElement {
  ruffle (version?: 1): {
    load (options: { data: ArrayBuffer, swfFileName: string }): Promise<void>;
    suspend (): void;
  };
}

interface RuffleGlobal {
  config?: Record<string, unknown>;
  newest? (): { createPlayer (): RufflePlayerElement } | null;
}

declare global {
  interface Window { RufflePlayer?: RuffleGlobal }
}

export default class FlashPlayer {

  private state: "idle" | "loading" | "playing" | "failed" = "idle";
  private player: RufflePlayerElement | null = null;

  /** Laid over the frame that gives the player its size; holds the Play button, then messages or the player. */
  private content: HTMLElement;

  private constructor (private container: HTMLElement) {
    this.content = container.querySelector(".flash-player-content");
    const button = this.content?.querySelector<HTMLButtonElement>(".flash-player-start");
    if (!button) return;

    button.addEventListener("click", () => this.start());
    button.hidden = false;
    this.content.querySelector(".flash-player-message")?.remove();

    // On Flash posts, the toolbar's Fullscreen button (and its hotkey) shows the movie fullscreen instead of
    // opening the file, which browsers can only download.
    document.querySelector(".ptbr-fullscreen-button")?.addEventListener("click", (event) => this.onFullscreenClick(event));

    // Like a video, the movie stops when the post gets blacklisted
    $(container).closest("#image-container").on("blk:hide.flashPlayer", () => this.hide());
  }

  /** Sets up the player on a post page that contains a Flash file. */
  public static initialize (): FlashPlayer | null {
    const container = document.getElementById("flash-player");
    return container ? new FlashPlayer(container) : null;
  }

  private async start (): Promise<void> {
    if (this.state === "loading" || this.state === "playing") return;
    this.state = "loading";
    this.showMessage("Loading…");

    const url = this.container.dataset.swf;
    try {
      // The movie is fetched here rather than by Ruffle, so that a missing file or a blocked request ends up in the
      // same fallback as every other failure.
      const [data] = await Promise.all([FlashPlayer.fetchMovie(url), FlashPlayer.loadRuffle(url)]);

      const ruffle = window.RufflePlayer?.newest?.();
      if (!ruffle) throw new Error("Ruffle did not start");

      const player = ruffle.createPlayer();
      this.content.replaceChildren(player);
      await player.ruffle(1).load({ data, swfFileName: new URL(url, document.baseURI).pathname.split("/").pop() });

      this.player = player;
      this.state = "playing";
      if (this.isBlacklisted()) this.hide(); // Blacklisted while it was loading
      else if (this.isFullscreen()) player.focus(); // So that keyboard input goes to the movie
    } catch (error) {
      console.error("Flash player:", error);
      this.state = "failed";
      this.exitFullscreen();
      this.showFailure();
    }
  }

  private onFullscreenClick (event: Event): void {
    event.preventDefault();
    if (this.isBlacklisted()) return;

    // Requested before anything is awaited: browsers only allow fullscreen right after a click or key press.
    this.requestFullscreen();
    void this.start(); // Does nothing if the movie is already playing
  }

  private hide (): void {
    this.player?.ruffle(1).suspend();
    this.exitFullscreen();
  }

  private isBlacklisted (): boolean {
    return !!this.container.closest("#image-container.blacklisted");
  }

  private isFullscreen (): boolean {
    return !!document.fullscreenElement && document.fullscreenElement === this.container;
  }

  private requestFullscreen (): void {
    if (typeof this.container.requestFullscreen !== "function") return; // e.g. iPhone: the movie plays inline
    try {
      this.container.requestFullscreen().catch((error) => console.warn("Flash player: fullscreen refused", error));
    } catch (error) {
      console.warn("Flash player: fullscreen refused", error);
    }
  }

  private exitFullscreen (): void {
    if (!this.isFullscreen()) return;
    document.exitFullscreen().catch(() => { /* Already left */ });
  }

  private showMessage (text: string): void {
    const message = document.createElement("p");
    message.className = "flash-player-message";
    message.textContent = text;
    this.content.replaceChildren(message);
  }

  private showFailure (): void {
    this.showMessage("The Flash player could not be started. You can still download the file.");
    const retry = document.createElement("button");
    retry.type = "button";
    retry.className = "st-button flash-player-retry";
    retry.textContent = "Try again";
    retry.addEventListener("click", () => this.start());
    this.content.append(retry);
  }

  private static async fetchMovie (url: string): Promise<ArrayBuffer> {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`The file could not be loaded (HTTP ${response.status})`);
    return response.arrayBuffer();
  }

  private static ruffleScript: Promise<void> | null = null;

  private static loadRuffle (movieUrl: string): Promise<void> {
    if (FlashPlayer.ruffleScript) return FlashPlayer.ruffleScript;

    const publicPath = `${import.meta.env.BASE_URL}${__RUFFLE_ASSET_DIR__}`;
    window.RufflePlayer = window.RufflePlayer ?? {};
    window.RufflePlayer.config = {
      publicPath,
      polyfills: false, // Only the player created here, never other <object>/<embed> elements on the page
      autoplay: "on", // The user has just pressed Play
      unmuteOverlay: "hidden",
      letterbox: "on", // Keeps the movie's shape when the player is shown fullscreen
      showSwfDownload: false, // The post page has its own Download options
      openUrlMode: "deny", // A movie cannot navigate to other sites
      allowScriptAccess: false, // A movie cannot call into the page
      base: new URL(movieUrl, document.baseURI).href, // Relative requests made by the movie resolve next to it
    };

    FlashPlayer.ruffleScript = new Promise<void>((resolve, reject) => {
      const script = document.createElement("script");
      script.src = `${publicPath}ruffle.js`;
      script.onload = () => resolve();
      script.onerror = () => {
        FlashPlayer.ruffleScript = null;
        script.remove();
        reject(new Error("Ruffle could not be loaded"));
      };
      document.head.append(script);
    });
    return FlashPlayer.ruffleScript;
  }
}
