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
    original: FileData;
    preview: FileData;
    sample: FileData;
  };

  private constructor () {
    const $element = $("#image-container");
    const data = PostCache.fromThumbnail($element);
    super(data);

    const resizeData = CurrentPost.loadResizeData();
    this.resizeData = {
      original: resizeData.original || { width: this.width, height: this.height, jpg: null, webp: null },
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

export interface FileData {
  width: number;
  height: number;
  jpg: string;
  webp: string;
}

