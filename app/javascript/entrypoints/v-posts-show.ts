// posts # show

import E621Type from "../src/js/interfaces/E621";
declare const E621: E621Type;

import "../src/js/pages/comments/comments";
import "../src/js/pages/posts/show/mod_queue";
import Note from "../src/js/pages/posts/show/notes";
import "../src/js/pages/posts/show/post_sets";
import "../src/js/pages/posts/show/PostsShowToolbar";
import "../src/js/pages/posts/show/recommended";
import "../src/js/pages/posts/show/related_tag";

import "../src/js/pages/post_flags/post_flags"; // We only need expandable notes from here

E621.Registry.register("v_posts_show", { Note });
