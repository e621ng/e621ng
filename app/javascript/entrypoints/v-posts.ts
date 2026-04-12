// posts

import E621Type from "../src/js/interfaces/E621";
declare const E621: E621Type;

import PostModeMenu from "../src/js/pages/posts/post_mode_menu";
import "../src/js/pages/posts/post_search";
import Post from "../src/js/pages/posts/posts";

E621.Registry.register("v_posts", { Post, PostModeMenu });
