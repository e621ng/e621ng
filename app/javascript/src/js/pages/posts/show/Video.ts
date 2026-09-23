import LStorage from "@/utility/storage/Local";
import { TimeSliderElement, VolumePopoverElement } from "@videojs/html";
import type { VideoPlayerElement } from "@videojs/html/video";

const seekingUpdateDelay = 150;

const videoJSImportModules = {
  base: () => [
    import("@videojs/html/ui/container"),
    import("@videojs/html/ui/controls"),
    import("@videojs/html/ui/gesture"),
    import("@videojs/html/ui/play-button"),
    import("@videojs/html/ui/time"),
    import("@videojs/html/ui/time-slider"),
    import("@videojs/html/ui/fullscreen-button"),
    import("@videojs/html/ui/seek-indicator"),
    // @ts-expect-error this thing doesn't have any d.ts file defined.
    import("@videojs/html/ui/popover"),
  ],
  sound: () => [
    import("@videojs/html/ui/volume-popover"),
    import("@videojs/html/ui/volume-slider"),
    import("@videojs/html/ui/mute-button"),
  ],
  extraOptions: () => [
    import("@videojs/html/ui/pip-button"),
    import("@videojs/html/ui/playback-rate-button"),
  ],
};


async function importVideoJS (extraModules: (Exclude<keyof typeof videoJSImportModules, "base">)[]) {
  // player must be loaded first
  await import("@videojs/html/video/player");

  // resolves all the requested imports for the base group and any other one supplied
  await Promise.all(["base", ...extraModules].flatMap(m => videoJSImportModules[m]()));
}

class VideoPlayer {
  protected videoElement: HTMLVideoElement;

  public constructor (protected containerElement: VideoPlayerElement) {
    this.videoElement = containerElement.querySelector("video");
    this.videoElement.addEventListener("volumechange", this.onSettingChange);
    this.videoElement.addEventListener("ratechange", this.onSettingChange);
  }

  protected onSettingChange = () => {
    this.storeSettings();
  };

  public storeSettings () {
    // muted != volume set to 0. we store both states to allow muting and unmuting while retaining vol.
    LStorage.Posts.Video.Volume = this.videoElement.volume;
    LStorage.Posts.Video.Muted = this.videoElement.muted;
    LStorage.Posts.Video.PlaybackRate = this.videoElement.playbackRate;
  }

  public loadSettings () {
    this.videoElement.volume = LStorage.Posts.Video.Volume;
    this.videoElement.muted = LStorage.Posts.Video.Muted;
    this.videoElement.playbackRate = LStorage.Posts.Video.PlaybackRate;
  }
}

class CustomVideoPlayer extends VideoPlayer {
  private slidingInterval: number;
  private isLoopable: boolean;
  private loadingVideoJsPromise: Promise<void>;
  private hasVolumeControls: boolean;

  private timeSliderElement: TimeSliderElement;


  public constructor (protected containerElement: VideoPlayerElement) {
    super(containerElement);
    this.isLoopable = this.videoElement.loop;

    this.timeSliderElement = containerElement.querySelector(".time-slider");
    this.timeSliderElement.addEventListener("drag-start", () => this.handleDragging("start"));
    this.timeSliderElement.addEventListener("drag-end", () => this.handleDragging("stop"));

    this.hasVolumeControls = this.containerElement.querySelector("media-mute-button") !== null;

    // load videojs here
    this.loadingVideoJsPromise = this.loadVideoJS();

    if (!this.hasVolumeControls) return; // nothing to do from here

    // fixes the volume popup not opening on mobile
    const volumePopup = containerElement.querySelector<VolumePopoverElement>(".volume-popup");
    containerElement.querySelector(".volume-button").addEventListener("touchstart", () => {
      volumePopup.open = !volumePopup.open;
    });
  }

  // seeks the actual video element when the user drags on the time slider
  private handleDragging (status: "start" | "stop") {
    if (status === "stop") {
      clearInterval(this.slidingInterval);
      this.videoElement.loop = this.isLoopable;
      return;
    }

    this.videoElement.loop = false; // this is to temporarily the player from constantly seeking to the start if the pointer is at the end
    this.slidingInterval = setInterval(() => {
      const seekingPercentage = parseFloat(this.timeSliderElement.style.getPropertyValue("--media-slider-pointer"));
      this.videoElement.currentTime = this.videoElement.duration * seekingPercentage / 100;
    }, seekingUpdateDelay);
  }

  private async loadVideoJS () {
    // do not import sound controls related modules if there's no sound to control
    await importVideoJS(this.hasVolumeControls ? ["extraOptions", "sound"] : ["extraOptions"]);

    // only do these after videojs has completely finished importing
    this.videoElement.controls = false;
    this.containerElement.querySelector("media-controls").classList.add("loaded");
  }

  public loadSettings (): void {
    // load settings after initializing videojs since it does override some previously set stuff
    this.loadingVideoJsPromise.then(() => super.loadSettings());
  }
}

function getPlayerType (): typeof VideoPlayer {
  return LStorage.Posts.VideoPlayer === "custom" ? CustomVideoPlayer : VideoPlayer;
}


(async () => {
  // only do anything here if there's a video in the page
  const videoContainer = $<VideoPlayerElement>(".video-player")[0];
  if (videoContainer === undefined) return;

  const player = new (getPlayerType())(videoContainer);

  player.loadSettings();
})();
