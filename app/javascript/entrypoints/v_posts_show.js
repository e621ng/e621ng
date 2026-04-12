// posts # show

window.E621.vLogger = new E621.Logger("Posts", "Show");

import "@/pages/comments/comments.js";
import "@/pages/posts/show/mod_queue.js";
import "@/pages/posts/show/notes.js";
import "@/pages/posts/show/post_sets.js";
import "@/pages/posts/show/PostsShowToolbar.js";
import "@/pages/posts/show/recommended.js";
import "@/pages/posts/show/related_tag.js";

import "@/pages/post_flags/post_flags.js"; // We only need expandable notes from here

window.E621.vLogger.log("Initialized");
