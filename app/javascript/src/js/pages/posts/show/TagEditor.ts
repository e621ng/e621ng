import HTTP from "@/utility/HTTP";
import Toast from "@/utility/Toast";

/**
 * Bootstrap for the posts#show tag editor (tag_editor.vue), mounted lazily on
 * the first edit-tab open — posts#show is a hot page, so Vue and the editor
 * chunk stay out of the initial load.
 */
export default class TagEditor {

  /* ============================== */
  /* ===== Singleton pattern ====== */
  /* ============================== */

  private static _instance: TagEditor | null = null;
  public static get instance (): TagEditor {
    if (!TagEditor._instance)
      TagEditor._instance = new TagEditor();
    return TagEditor._instance;
  }


  /* ============================== */
  /* ======= Initialization ======= */
  /* ============================== */

  // Blocks concurrent double-mounts; reset on failure below so the next
  // tab-open can retry.
  private mounted = false;

  private constructor () {
    if (TagEditor._instance)
      throw new Error("TagEditor is a singleton class. Use TagEditor.instance to access the instance.");

    // Not .one(): a failed mount (e.g. a chunk import lost to a network flake)
    // resets the flag above, and the next tab-open retries.
    // jQuery listener: EditTab announces the open with $.trigger, which native listeners don't see.
    $(document).on("danbooru:open-post-edit-tab", () => {
      this.mount().catch(console.error);
    });
  }

  private async mount (): Promise<void> {
    if (this.mounted) return;
    this.mounted = true;

    try {
      // Import Vue as needed
      const [{ createApp }, { default: TagEditorApp }, uploadTagsData] = await Promise.all([
        import("vue"),
        import("./tag_editor.vue"),
        HTTP.getJSON("/users/upload_tags.json").catch(() => {
          // Tolerated: the editor mounts with empty Quick Tags / Recent.
          Toast.alert("Failed to load upload tags. Please refresh the page.");
        }),
      ]);

      const mountPoint = document.getElementById("tag-string-editor");
      const app = createApp(TagEditorApp, {
        postTags: mountPoint?.dataset.tags ?? "",
        uploadTags: uploadTagsData?.upload_tags ?? [],
        recentTags: uploadTagsData?.recent_tags ?? [],
      });
      app.mount("#tag-string-editor");
      $("#tag-string-editor").removeClass("pending");
    } catch (error) {
      this.mounted = false;
      Toast.alert("Failed to load the tag editor. Please try again.");
      throw error;
    }
  }
}
