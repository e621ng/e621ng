// posts # show

import ModuleRegistry from "@/utility/ModuleRegistry";

import CurrentPost from "@/models/CurrentPost";
import "@/pages/comments/comments";
import AddToPoolDialog from "@/pages/posts/show/AddToPoolDialog";
import AddToSetDialog from "@/pages/posts/show/AddToSetDialog";
import ApprovalToolbar from "@/pages/posts/show/ApprovalToolbar";
import "@/pages/posts/show/BlacklistRevealOnClick";
import DeleteWithReasonDialog from "@/pages/posts/show/DeleteWithReasonDialog";
import DetailedRejectionDialog from "@/pages/posts/show/DetailedRejectionDialog";
import EditTab from "@/pages/posts/show/EditTab";
import "@/pages/posts/show/MobileTabs";
import Navigation from "@/pages/posts/show/Navigation";
import Note from "@/pages/posts/show/notes";
import PostActions from "@/pages/posts/show/PostActions";
import PostSet from "@/pages/posts/show/PostSet";
import RelationshipPreview from "@/pages/posts/show/RelationshipPreview";
import "@/pages/posts/show/toolbar";
import Recommended from "@/pages/posts/show/Recommended";
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
  void DetailedRejectionDialog.instance;
  void DeleteWithReasonDialog.instance;
  void ApprovalToolbar.instance;
  void Recommended.instance;
  PostSet.bindRemoveLinks();
  PostReowner.initialize_links();
  Navigation.registerHotkeys();
  PostActions.bind();
  RelationshipPreview.initialize();
  EditTab.initialize();
});
