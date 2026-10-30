// posts # index

import ModuleRegistry from "@/utility/ModuleRegistry";
import State from "@/utility/StateUtils";

import PostModeMenu from "@/pages/posts/index/PostModeMenu";
import WikiExcerpt from "@/pages/posts/index/WikiExcerpt";

State.onReady(() => {
  void PostModeMenu.instance;
  void WikiExcerpt.instance;

  ModuleRegistry.register("v_posts_index", { PostModeMenu: PostModeMenu.instance });
});
