// posts

import ModuleRegistry from "@/utility/ModuleRegistry";
import State from "@/utility/StateUtils";

import BlacklistQuickEdit from "@/components/BlacklistQuickEdit";
import BlacklistQuickToggle from "@/pages/posts/common/BlacklistQuickToggle";
import BulkActions from "@/pages/posts/BulkActions";
import PostSearchInput from "@/pages/posts/common/PostSearchInput";
import RandomPost from "@/pages/posts/common/RandomPost";
import SearchControls from "@/pages/posts/common/SearchControls";
import SearchFilters from "@/pages/posts/common/SearchFilters";
import TagListCollapse from "@/pages/posts/common/TagListCollapse";

// Keep this list in sync with v_favorites.ts
State.onReady(() => {
  void BlacklistQuickEdit.instance;
  void BlacklistQuickToggle.instance;
  void SearchControls.instance;
  void SearchFilters.instance;
  void TagListCollapse.instance;
  void RandomPost.instance;
  void PostSearchInput.instance;

  ModuleRegistry.register("v_posts", { Post: BulkActions });
});
