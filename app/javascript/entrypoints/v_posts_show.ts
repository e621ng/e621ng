// posts # show

import E621Type from "@/interfaces/E621";
declare const E621: E621Type;

import "@/pages/comments/comments";
import "@/pages/posts/show/AddToPoolDialog";
import "@/pages/posts/show/CurrentPost";
import "@/pages/posts/show/MobileTabs";
import "@/pages/posts/show/mod_queue";
import Note from "@/pages/posts/show/notes";
import "@/pages/posts/show/post_sets";
import "@/pages/posts/show/PostsShowToolbar";
import "@/pages/posts/show/recommended";
import "@/pages/posts/show/related_tag";
import "@/pages/posts/show/ResizeHandler";
import "@/pages/posts/show/SwipeGestureHandler";

import "@/pages/post_flags/post_flags"; // We only need expandable notes from here
import CurrentPost from "@/pages/posts/show/CurrentPost";

E621.Registry.register("v_posts_show", { Note, CurrentPost });
