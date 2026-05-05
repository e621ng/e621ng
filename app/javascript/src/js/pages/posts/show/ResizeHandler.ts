import Logger from "@/utility/Logger";
import CurrentPost, { FileData } from "./CurrentPost";

export default class ResizeHandler {

  private Logger: Logger;
  private post: CurrentPost;

  private $selector: JQuery<HTMLElement>;
  private $target: JQuery<HTMLElement>;

  private ResizeList: Record<string, FileData> = {};

  constructor () {
    this.Logger = new Logger("ResizeHandler");
    this.post = CurrentPost.instance;

    this.$selector = $("#image-resize-selector");
    this.$target = $("#posts-show-image");

    // Intelligently set resize URLs based on viewport size
    this.ResizeList = {
      "original": this.post.resizeData.original,
      "fitv": $(window).height() >= 850 ? this.post.resizeData.original : this.post.resizeData.sample,
      "fit": $(window).width() >= 850 ? this.post.resizeData.original : this.post.resizeData.sample,
      "large": this.post.resizeData.sample,
    };
    this.Logger.log(`Initialized with ${Object.keys(this.ResizeList).length} resize options`);

    // Listen to selector changes
    this.$selector.on("change", () => {
      const selected = this.$selector.val() as string;
      this.Logger.log(`Resize option selected: ${selected}`);

      if (!this.ResizeList[selected]) {
        console.warn("Unknown resize option selected:", selected);
        return;
      }

      const resizeData = this.ResizeList[selected];
      this.$target.attr("data-size", selected);
      this.updateImageSize(resizeData);
    });
  }


  private updateImageSize (resizeData: FileData) {
    const imageTag = this.$target.find("img");

    if (!imageTag.length) {
      console.error("Image tag not found in target element");
      return;
    }

    if (imageTag.attr("src") === resizeData.jpg) {
      this.Logger.log("Image already at desired size, skipping update");
      return;
    }

    imageTag.attr({
      src: resizeData.jpg,
      width: resizeData.width,
      height: resizeData.height,
    });

    if (resizeData.webp) {
      const el = this.$target.find("source");
      if (el.length == 0)
        $("<source>").attr({
          srcset: resizeData.webp,
          type: "image/webp",
        }).prependTo(this.$target);
      else
        el.attr({
          srcset: resizeData.webp,
        });
    } else this.$target.find("source").remove();
  }
}

$(() => {
  new ResizeHandler();
});
