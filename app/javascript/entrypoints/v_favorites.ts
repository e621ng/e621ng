// favorites

import E621Type from "@/interfaces/E621";
declare const E621: E621Type;

import "@/pages/posts/BlacklistQuickEdit";
import "@/pages/posts/BlacklistQuickToggle";
import "@/pages/posts/post_search";
import "@/pages/posts/SearchControls";
import "@/pages/posts/SearchFilters";

E621.Registry.register("v_favorites");
