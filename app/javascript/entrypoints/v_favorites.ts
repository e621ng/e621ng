// favorites

import ModuleRegistry from "@/utility/ModuleRegistry";

import "@/pages/posts/BlacklistQuickEdit";
import "@/pages/posts/BlacklistQuickToggle";
import BulkActions from "@/pages/posts/BulkActions";
import PostModeMenu from "@/pages/posts/PostModeMenu";
import PostSearchInput from "@/pages/posts/PostSearchInput";
import RandomPost from "@/pages/posts/RandomPost";
import "@/pages/posts/SearchControls";
import "@/pages/posts/SearchFilters";
import TagListCollapse from "@/pages/posts/TagListCollapse";
import WikiExcerpt from "@/pages/posts/WikiExcerpt";

ModuleRegistry.register("v_favorites", { Post: BulkActions, PostModeMenu });

$(() => {
  PostModeMenu.initialize();
  TagListCollapse.initialize();
  RandomPost.registerHotkey();
  PostSearchInput.initialize();
  WikiExcerpt.initialize();
});
