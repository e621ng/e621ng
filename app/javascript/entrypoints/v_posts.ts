// posts

import ModuleRegistry from "@/utility/ModuleRegistry";

import "@/pages/posts/BlacklistQuickEdit";
import "@/pages/posts/BlacklistQuickToggle";
import PostModeMenu from "@/pages/posts/post_mode_menu";
import "@/pages/posts/post_search";
import Post from "@/pages/posts/posts";
import "@/pages/posts/SearchControls";
import "@/pages/posts/SearchFilters";

ModuleRegistry.register("v_posts", { Post, PostModeMenu });
