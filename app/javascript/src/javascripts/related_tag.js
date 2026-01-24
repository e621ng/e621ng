import $ from "jquery";

const RelatedTag = {};

RelatedTag.tag_editor_setup = false;
RelatedTag.init_post_show_editor = async function () {
  if (RelatedTag.tag_editor_setup) return;
  RelatedTag.tag_editor_setup = true;

  // Import Vue as needed
  const [{ createApp }, { default: TagEditor }] = await Promise.all([
    import("vue"),
    import("./tag_editor.vue"),
  ]);

  const app = createApp(TagEditor);
  app.mount("#tag-string-editor");
  $("#tag-string-editor").trigger("e6ng:vue-mounted");
};

$(function () {
  $(document).one("danbooru:open-post-edit-tab", () => {
    RelatedTag.init_post_show_editor().catch(console.error);
  });
});

export default RelatedTag;
