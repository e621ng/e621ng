// posts # show

window.E621.vLogger = new E621.Logger("Posts", "Show");

import "@/pages/comments/comments";
import "@/pages/posts/show/mod_queue";
import "@/pages/posts/show/notes";
import "@/pages/posts/show/post_sets";
import "@/pages/posts/show/PostsShowToolbar";
import "@/pages/posts/show/recommended";
import "@/pages/posts/show/related_tag";

import "@/pages/post_flags/post_flags"; // We only need expandable notes from here

window.E621.vLogger.log("Initialized");
