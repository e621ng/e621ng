// posts # show

import ModuleRegistry from "@/utility/ModuleRegistry";

import CurrentPost from "@/models/CurrentPost";
import "@/pages/comments/comments";
import AddToPoolDialog from "@/pages/posts/show/AddToPoolDialog";
import AddToSetDialog from "@/pages/posts/show/AddToSetDialog";
import "@/pages/posts/show/BlacklistRevealOnClick";
import "@/pages/posts/show/MobileTabs";
import "@/pages/posts/show/mod_queue";
import Note from "@/pages/posts/show/notes";
import PostSet from "@/pages/posts/show/PostSet";
import "@/pages/posts/show/toolbar";
import "@/pages/posts/show/recommended";
import "@/pages/posts/show/TagEditor";
import PostResizer from "@/pages/posts/show/Resizer";
import "@/pages/posts/show/SwipeGestureHandler";
import "@/pages/posts/show/Video";
import PostReowner from "@/pages/staff/post/posts/PostReowner";


import "@/pages/post_flags/post_flags"; // We only need expandable notes from here

ModuleRegistry.register("v_posts_show", { Note, CurrentPost, PostResizer });

$(() => {
  void AddToPoolDialog.instance;
  void AddToSetDialog.instance;
  PostSet.bindRemoveLinks();
  PostReowner.initialize_links();
});
