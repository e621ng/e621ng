import PostCache, { CachedPost } from "@/models/PostCache";

export default class CurrentPost extends CachedPost {

  private static _instance: CurrentPost;
  public static get instance () {
    if (!CurrentPost.isAvailable) return null;
    if (!CurrentPost._instance)
      CurrentPost._instance = new CurrentPost();
    return CurrentPost._instance;
  }

  private static _isAvailable: boolean;
  public static get isAvailable () {
    if (CurrentPost._isAvailable === undefined)
      CurrentPost._isAvailable = !!document.getElementById("image-container");
    return CurrentPost._isAvailable;
  }

  public resizeData: {
    original: OriginalFileData;
    preview: PreviewFileData;
    sample: PreviewFileData;
  };

  private constructor () {
    const $element = $("#image-container");
    const data = PostCache.fromThumbnail($element);
    super(data);

    const resizeData = CurrentPost.loadResizeData();
    this.resizeData = {
      original: resizeData.original || { width: this.width, height: this.height, url: null },
      preview: resizeData.preview || { width: 150, height: 150, jpg: null, webp: null },
      sample: resizeData.sample || { width: this.width, height: this.height, jpg: null, webp: null },
    };
  }

  private static loadResizeData () {
    try {
      const base64 = document.getElementById("post-resize-data").textContent;
      const json = atob(base64);
      return JSON.parse(json);
    } catch (e) {
      console.error("Failed to load post resize data:", e);
      return {};
    }
  }
}

interface ImageFileData {
  width: number;
  height: number;
}

interface OriginalFileData extends ImageFileData {
  url: string;
}

interface PreviewFileData extends ImageFileData {
  jpg: string;
  webp: string;
}

