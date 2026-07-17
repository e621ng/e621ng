// posts # show

import E621Type from "@/interfaces/E621";
declare const E621: E621Type;

import CurrentPost from "@/models/CurrentPost";
import "@/pages/comments/comments";
import "@/pages/posts/show/AddToPoolDialog";
import "@/pages/posts/show/BlacklistRevealOnClick";
import "@/pages/posts/show/MobileTabs";
import "@/pages/posts/show/mod_queue";
import Note from "@/pages/posts/show/notes";
import PostSet from "@/pages/posts/show/PostSet";
import "@/pages/posts/show/PostsShowToolbar";
import "@/pages/posts/show/recommended";
import "@/pages/posts/show/related_tag";
import PostResizer from "@/pages/posts/show/Resizer";
import "@/pages/posts/show/SwipeGestureHandler";
import PostReowner from "@/pages/staff/post/posts/PostReowner";

import "@/pages/post_flags/post_flags"; // We only need expandable notes from here

E621.Registry.register("v_posts_show", { Note, CurrentPost, PostResizer });

$(() => {
  PostSet.initialize_add_to_set_link();
  PostSet.initialize_remove_from_set_links();
  PostReowner.initialize_links();
});
