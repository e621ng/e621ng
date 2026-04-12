// posts

import E621Type from "@/interfaces/E621";
declare const E621: E621Type;

import PostModeMenu from "@/pages/posts/post_mode_menu";
import "@/pages/posts/post_search";
import Post from "@/pages/posts/posts";

E621.Registry.register("v-posts", { Post, PostModeMenu });
