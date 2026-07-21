import Hotkeys from "@/core/hotkeys";
import CurrentPost from "@/models/CurrentPost";
import Logger from "@/utility/Logger";
import Settings from "@/utility/Settings";
import State from "@/utility/StateUtils";
import LStorage from "@/utility/storage/Local";

/**
 * Owns the posts#show media sizing UI: the resize selector, the resize hotkey,
 * and swapping the image/video source + fit classes.
 *
 * The server renders the correct initial src + class (see _image.html.erb and
 * PostPresenter#initial_image_class/url), so on load this only syncs the selector
 * — it does not mutate the DOM, avoiding the historical on-load reflow. It reacts
 * to explicit user actions (selector change / hotkey) thereafter.
 */
class PostResizer {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: PostResizer | null = null;
  public static get instance (): PostResizer {
    if (!PostResizer._instance)
      PostResizer._instance = new PostResizer();
    return PostResizer._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  private isAvailable = false; // Whether the current post can be resized
  private tookOverImage = false; // Whether the client has taken over image source selection
  private hasWebpSupport = false;

  private Logger = new Logger("Resizer");

  private constructor () {
    if (PostResizer._instance)
      throw new Error("PostResizer is a singleton class. Use PostResizer.instance to access the instance.");

    PostResizer.testWebpSupport().then((support) => {
      this.hasWebpSupport = support;
      State.onReady(() => this.initialize());
    });
  }

  private initialize () {
    if (!CurrentPost.exists) return;
    if (!CurrentPost.is.visible || CurrentPost.is.flash) return;

    // Sanity check for image/video element actually being present.
    if (CurrentPost.is.image && !$("img#image").length) {
      this.Logger.error("CurrentPost is an image, but no <img> tag was found.");
      return;
    }
    if (CurrentPost.is.video && !$("video#image").length) {
      this.Logger.error("CurrentPost is a video, but no <video> tag was found.");
      return;
    }

    this.isAvailable = true;

    if (CurrentPost.is.image)
      $("img#image").on("load.resizer", () => $("#image-container").removeClass("image-loading"));

    // "Resize to original" link"
    $("#image-resize-link").on("click.resizer", (e) => {
      e.preventDefault();
      this.resizeTo("fit");
    });

    // Dropdown selector
    $<HTMLSelectElement>("select#image-resize-selector").on("change.resizer", (event) => this.resizeTo(event.target.value));

    Hotkeys.register("resize", () => this.resizeTo("next"));

    // Videos have multiple samples — need to determine which one is relevant
    if (CurrentPost.is.video && CurrentPost.initial_size === "large")
      this.resizeTo(this.bestVideoSampleSize());
  }


  /* ============================== */
  /* ========= Public API ========= */
  /* ============================== */

  /**
   * Resizes the current post to the specified size, if possible.
   * @param targetSize The target size to resize to.
   */
  public resizeTo (targetSize: string) {
    if (!this.isAvailable) {
      this.Logger.error("Resizer.resizeTo called on a post that cannot be resized.");
      return;
    }

    if (targetSize === "next") {
      const options = [];
      let selected = 0;
      $("#image-resize-selector").children("option").each((index, option) => {
        options.push(String($(option).val()));
        if ($(option).is(":selected")) selected = index;
      });

      this.resizeTo(options[(selected + 1) % options.length]);
      return;
    }

    targetSize = this.updateSizeSelector(targetSize);

    if (CurrentPost.is.video)
      this.resizeVideo(targetSize);
    else this.resizeImage(targetSize);
  }


  /* ============================== */
  /* ========= Image sizing ======= */
  /* ============================== */

  private resizeImage (targetSize: string) {
    const $image = $("img#image");
    const $notice = $("#image-resize-notice");
    $notice.hide();

    // Clean up server-rendered sources – client does not use them
    if (!this.tookOverImage) {
      $("#image-container picture source").remove();
      this.tookOverImage = true;
    }

    let desiredUrl: string | null | undefined;
    const desiredClasses: string[] = [];

    switch (targetSize) {
      case "original":
        desiredUrl = CurrentPost.files.original.url;
        break;
      case "fit":
        desiredClasses.push("fit-window");
        desiredUrl = CurrentPost.files.original.url;
        break;
      case "fitv":
        desiredClasses.push("fit-window-vertical");
        desiredUrl = CurrentPost.files.original.url;
        break;
      case "large":
      default:
        if (targetSize !== "large")
          this.Logger.error(`Unknown target size: ${targetSize}`);

        $notice.show();
        desiredClasses.push("fit-window");

        if (Settings.Posts.webp_enabled && CurrentPost.files.sample.webp && this.hasWebpSupport)
          desiredUrl = CurrentPost.files.sample.webp;
        else desiredUrl = CurrentPost.files.sample.jpg;

        this.updateResizePercentage(CurrentPost.files.sample.width, CurrentPost.files.original.width);
    }

    $image.removeClass().addClass(desiredClasses);
    if ($image.attr("src") !== desiredUrl) {
      $("#image-container").addClass("image-loading");
      $image.attr("src", desiredUrl);
    }
  }


  /* ============================== */
  /* ========= Video sizing ======= */
  /* ============================== */

  private resizeVideo (targetSize: string) {
    const $video = $("video#image");
    const videoTag = $video[0] as HTMLVideoElement;
    const $notice = $("#image-resize-notice");
    $notice.hide();

    let targetSources: { type: string, url: string | null | undefined }[] = [];
    const desiredClasses: string[] = [];

    switch (targetSize) {
      case "source":
        targetSources = this.calculateVideoSources(true);
        break;
      case "original":
        targetSources = this.calculateVideoSources();
        break;
      case "fit":
        targetSources = this.calculateVideoSources();
        desiredClasses.push("fit-window");
        break;
      case "fitv":
        targetSources = this.calculateVideoSources();
        desiredClasses.push("fit-window-vertical");
        break;
      default: {
        $notice.show();

        const targetVideo = CurrentPost.files.video.samples?.[targetSize];
        if (!targetVideo) {
          console.error(`No video found for target size: ${targetSize}`);
          return;
        }

        targetSources.push({
          type: "video/mp4; codecs=\"avc1.4D401E\"",
          url: targetVideo?.url,
        });

        desiredClasses.push("fit-window");
        this.updateResizePercentage(targetVideo.width, CurrentPost.files.original.width);
        break;
      }
    }

    $video.empty(); // Remove existing sources, to prevent the browser from trying to use them.

    let foundPlayable = false;
    for (const source of targetSources) {
      // canPlayType can return "probably", "maybe" or "".
      // * "maybe" means that the browser cannot determine whether it can play the file until playback is attempted.
      // * "probably" indicates that the browser thinks it can play the file, and seems to be returned only if the codec is provided.
      // * "" means that the browser cannot play the file. It will also throw an error in the console.
      if (!videoTag.canPlayType(source.type)) continue;
      foundPlayable = true;

      if (source.url === $video.attr("src")) break;

      this.playVideoFile(videoTag, source.url);
      break;
    }

    if (!foundPlayable)
      this.playVideoFile(videoTag, CurrentPost.files.original.url);

    $video.removeClass().addClass(desiredClasses);
  }

  /** Collates the non-downscaled video sources */
  private calculateVideoSources (skipVariants = LStorage.Posts.SkipVariants) {
    const result: { type: string, url: string | null | undefined }[] = [];

    // Add the original file first.
    // Unprocessed posts will not have a codec string on file, which makes feature detection harder
    const originalCodec = CurrentPost.files.video.original.codec;
    result.push({
      type: originalCodec ? `video/${CurrentPost.files.meta.ext}; codecs="${originalCodec}"` : `video/${CurrentPost.files.meta.ext}`,
      url: CurrentPost.files.original.url,
    });

    // Add fallback variants if they exist.
    // The "Source" view does not display these.
    if (Object.keys(CurrentPost.files.video.variants).length && !skipVariants)
      for (const [filetype, data] of Object.entries(CurrentPost.files.video.variants)) {
        if (!data.url) continue;
        result.push({
          type: `video/${filetype}; codecs="${data.codec}"`,
          url: data.url,
        });
      }

    return result;
  }

  /**
   * Plays a video file in the specified video tag.
   * @param videoTag HTML tag of the video player
   * @param sourceURL New video source URL
   */
  private playVideoFile (videoTag: HTMLVideoElement, sourceURL: string | null | undefined) {
    if (!sourceURL) return;
    const wasPaused = videoTag.paused;
    if (!wasPaused) videoTag.pause(); // Otherwise size changes won't take effect.
    const time = videoTag.currentTime;

    videoTag.setAttribute("src", sourceURL);
    videoTag.load(); // Forces changed source to take effect. *SOME* browsers ignore changes otherwise.

    // Resume playback at the original time
    videoTag.currentTime = time;
    if (!wasPaused) videoTag.play();
  }

  private bestVideoSampleSize (): string {
    const samples = Object.entries(CurrentPost.files.video.samples);
    if (samples.length === 0) return "fitv";

    const fitWidth = $("#image-container").width(),
      fitHeight = window.outerHeight;

    let latest = "fitv";
    for (const [name, data] of samples.reverse()) {
      latest = name;
      if ((fitHeight - (data.height ?? 0)) < 0 || (fitWidth - (data.width ?? 0)) < 0) continue;
      return name;
    }
    return latest;
  }


  /* ============================== */
  /* ======== Class Methods ======= */
  /* ============================== */

  /**
   * Updates the resize selector to the specified choice, if it exists.
   * Falls back to "fit" if the choice is not found.
   * @param choice The choice to select in the resize selector.
   * @returns The choice that was actually selected.
   */
  private updateSizeSelector (choice: string): string {
    const selector = document.getElementById("image-resize-selector") as HTMLSelectElement;

    for (const item of document.querySelectorAll<HTMLOptionElement>("#image-resize-selector option")) {
      if (item.value !== choice) continue;
      selector.value = choice;
      return choice;
    }

    selector.value = "fit";
    return "fit";
  }

  private updateResizePercentage (width: number | undefined, origWidth: number | undefined) {
    const $percentage = $("#image-resize-size");
    const scaledPercentage = Math.floor(100 * (width ?? 0) / (origWidth ?? 1));
    $percentage.text(`${scaledPercentage}%`);
  }


  /* ============================== */
  /* ======== Static Methods ====== */
  /* ============================== */

  private static async testWebpSupport (): Promise<boolean> {
    if (!self.createImageBitmap) return false;

    const webpData = "data:image/webp;base64,UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAwA0JaQAA3AA/vuUAAA=";
    return new Promise((resolve) => {
      const img = new Image();
      img.onload = () => resolve(img.width > 0 && img.height > 0);
      img.onerror = () => resolve(false);
      img.src = webpData;
    });
  }
}

export default PostResizer.instance;
