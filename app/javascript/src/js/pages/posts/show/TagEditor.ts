import HTTP from "@/utility/HTTP";
import Toast from "@/utility/Toast";

// Bootstrap for the posts#show tag editor (tag_editor.vue), mounted lazily on
// the first edit-tab open — posts#show is a hot page, so Vue and the editor
// chunk stay out of the initial load.
const TagEditorModule = {
  // Blocks concurrent double-mounts; reset on failure below so the next
  // tab-open can retry.
  initialized: false,

  async init () {
    if (this.initialized) return;
    this.initialized = true;

    try {
      // Import Vue as needed
      const [{ createApp }, { default: TagEditor }, uploadTagsData] = await Promise.all([
        import("vue"),
        import("./tag_editor.vue"),
        HTTP.getJSON("/users/upload_tags.json").catch(() => {
          // Tolerated: the editor mounts with empty Quick Tags / Recent.
          Toast.alert("Failed to load upload tags. Please refresh the page.");
        }),
      ]);

      const mountPoint = document.getElementById("tag-string-editor");
      const app = createApp(TagEditor, {
        postTags: mountPoint?.dataset.tags ?? "",
        uploadTags: uploadTagsData?.upload_tags ?? [],
        recentTags: uploadTagsData?.recent_tags ?? [],
      });
      app.mount("#tag-string-editor");
      $("#tag-string-editor").removeClass("pending");
    } catch (error) {
      this.initialized = false;
      Toast.alert("Failed to load the tag editor. Please try again.");
      throw error;
    }
  },
};

$(function () {
  // Not .one(): a failed init (e.g. a chunk import lost to a network flake)
  // resets the flag above, and the next tab-open retries.
  $(document).on("danbooru:open-post-edit-tab", () => {
    TagEditorModule.init().catch(console.error);
  });
});

export default TagEditorModule;
