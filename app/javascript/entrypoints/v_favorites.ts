// favorites

import ModuleRegistry from "@/utility/ModuleRegistry";
import State from "@/utility/StateUtils";

import BlacklistQuickEdit from "@/pages/posts/BlacklistQuickEdit";
import BlacklistQuickToggle from "@/pages/posts/BlacklistQuickToggle";
import BulkActions from "@/pages/posts/BulkActions";
import PostModeMenu from "@/pages/posts/PostModeMenu";
import PostSearchInput from "@/pages/posts/PostSearchInput";
import RandomPost from "@/pages/posts/RandomPost";
import SearchControls from "@/pages/posts/SearchControls";
import SearchFilters from "@/pages/posts/SearchFilters";
import TagListCollapse from "@/pages/posts/TagListCollapse";
import WikiExcerpt from "@/pages/posts/WikiExcerpt";

State.onReady(() => {
  void BlacklistQuickEdit.instance;
  void BlacklistQuickToggle.instance;
  void SearchControls.instance;
  void SearchFilters.instance;
  void PostModeMenu.instance;
  void TagListCollapse.instance;
  void RandomPost.instance;
  void PostSearchInput.instance;
  void WikiExcerpt.instance;

  ModuleRegistry.register("v_favorites", { Post: BulkActions, PostModeMenu: PostModeMenu.instance });
});
