const RelatedTag = {};

import TagEditor from "./tag_editor.vue";
import { createApp } from "vue";

RelatedTag.tag_editor_setup = false;
RelatedTag.init_post_show_editor = function () {
  if (RelatedTag.tag_editor_setup)
    return;
  RelatedTag.tag_editor_setup = true;

  const app = createApp(TagEditor);
  app.mount("#tag-string-editor");
};

$(function () {
  $(document).on("danbooru:open-post-edit-tab", RelatedTag.init_post_show_editor);
});
