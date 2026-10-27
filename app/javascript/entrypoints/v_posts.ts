// posts

import ModuleRegistry from "@/utility/ModuleRegistry";

import "@/pages/posts/BlacklistQuickEdit";
import "@/pages/posts/BlacklistQuickToggle";
import BulkActions from "@/pages/posts/BulkActions";
import PostModeMenu from "@/pages/posts/post_mode_menu";
import "@/pages/posts/post_search";
import RandomPost from "@/pages/posts/RandomPost";
import "@/pages/posts/SearchControls";
import "@/pages/posts/SearchFilters";
import TagListCollapse from "@/pages/posts/TagListCollapse";

ModuleRegistry.register("v_posts", { Post: BulkActions, PostModeMenu });

$(() => {
  TagListCollapse.initialize();
  RandomPost.registerHotkey();
});
