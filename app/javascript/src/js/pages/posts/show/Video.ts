import LStorage from "@/utility/storage/Local";
import TimingUtils from "@/utility/TimingUtils";
import { TimeSliderElement, VolumePopoverElement } from "@videojs/html";
import type { VideoPlayerElement } from "@videojs/html/video";

const seekingUpdateDelay = 50;


async function importVideoJS () {
  // player must be loaded first
  await import("@videojs/html/video/player");

  await Promise.all([
    import("@videojs/html/ui/container"),
    import("@videojs/html/ui/controls"),
    import("@videojs/html/ui/gesture"),
    import("@videojs/html/ui/play-button"),
    import("@videojs/html/ui/time"),
    import("@videojs/html/ui/volume-popover"),
    import("@videojs/html/ui/volume-slider"),
    import("@videojs/html/ui/mute-button"),
    import("@videojs/html/ui/time-slider"),
    import("@videojs/html/ui/fullscreen-button"),
    import("@videojs/html/ui/pip-button"),
    import("@videojs/html/ui/playback-rate-button"),
    import("@videojs/html/ui/seek-indicator"),
    // @ts-expect-error this thing doesn't have any d.ts file defined.
    import("@videojs/html/ui/popover"),
  ]);
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
    LStorage.Posts.Video.Loop = this.videoElement.loop;
  }

  public loadSettings () {
    this.videoElement.volume = LStorage.Posts.Video.Volume;
    this.videoElement.muted = LStorage.Posts.Video.Muted;
    this.videoElement.playbackRate = LStorage.Posts.Video.PlaybackRate;
    this.videoElement.loop = LStorage.Posts.Video.Loop;
  }
}

class CustomVideoPlayer extends VideoPlayer {
  private loadingVideoJsPromise: Promise<void>;

  private timeSliderElement: TimeSliderElement;
  private loopButton: HTMLButtonElement;


  public constructor (protected containerElement: VideoPlayerElement) {
    super(containerElement);
    this.loadingVideoJsPromise = this.loadVideoJS();

    this.timeSliderElement = containerElement.querySelector(".time-slider");
    this.timeSliderElement.addEventListener("drag-start", () => this.handleDraggingChange("start"));
    this.timeSliderElement.addEventListener("drag-end", () => this.handleDraggingChange("stop"));

    this.loopButton = containerElement.querySelector(".loop-button");
    this.loopButton.addEventListener("click", () => {
      this.videoElement.loop = !this.videoElement.loop;
      this.updateLoopState(true);
    });

    // fixes the volume popup not opening on mobile
    const volumePopup = containerElement.querySelector<VolumePopoverElement>(".volume-popup");
    containerElement.querySelector(".volume-button").addEventListener("touchstart", () => {
      volumePopup.open = !volumePopup.open;
    });
  }


  private updateLoopState = (save: boolean = false) => {
    this.loopButton.classList.toggle("enabled", this.videoElement.loop);
    if (save) this.storeSettings();
  };

  // seeks the actual video element when the user drags on the time slider
  // throttled to prevent exhausting the player
  private handleDraggingMove = TimingUtils.throttle(() => {
    const seekingPercentage = parseFloat(this.timeSliderElement.style.getPropertyValue("--media-slider-pointer"));
    this.videoElement.currentTime = this.videoElement.duration * seekingPercentage / 100;
  }, seekingUpdateDelay);

  // starts or stops listening to changes to seeking
  private handleDraggingChange (status: "start" | "stop") {
    if (status === "stop") {
      this.timeSliderElement.removeEventListener("pointermove", this.handleDraggingMove);
      this.videoElement.loop = LStorage.Posts.Video.Loop;
      return;
    }

    this.videoElement.loop = false; // this is to temporarily the player from constantly seeking to the start if the pointer is at the end
    this.timeSliderElement.addEventListener("pointermove", this.handleDraggingMove); // only fire when pointer moves
  }

  private async loadVideoJS () {
    await importVideoJS();

    // only do these after videojs has completely finished importing
    this.videoElement.controls = false;
    this.containerElement.querySelector("media-controls").classList.add("loaded");
  }

  public loadSettings (): void {
    // load settings after initializing videojs since it does override some previously set stuff
    this.loadingVideoJsPromise.then(() => {
      super.loadSettings();
      this.updateLoopState();
    });
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
