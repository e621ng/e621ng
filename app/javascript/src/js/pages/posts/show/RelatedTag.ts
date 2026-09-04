import HTTP from "@/utility/HTTP";
import Toast from "@/utility/Toast";

export default class RelatedTag {
  private static tag_editor_setup = false;

  public static async init_post_show_editor () {
    if (RelatedTag.tag_editor_setup) return;
    RelatedTag.tag_editor_setup = true;

    // Import Vue as needed
    const [{ createApp }, { default: TagEditor }, uploadTagsData] = await Promise.all([
      import("vue"),
      import("./tag_editor.vue"),
      HTTP.getJSON("/users/upload_tags.json").catch(() => {
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
    $("#tag-string-editor")
      .removeClass("pending")
      .trigger("e6ng:vue-mounted");
  }
}

$(function () {
  $(document).one("danbooru:open-post-edit-tab", () => {
    RelatedTag.init_post_show_editor().catch(console.error);
  });
});
