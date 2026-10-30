// posts # show

import ModuleRegistry from "@/utility/ModuleRegistry";
import State from "@/utility/StateUtils";

import CurrentPost from "@/models/CurrentPost";
import "@/pages/comments/comments";
import AddToPoolDialog from "@/pages/posts/show/AddToPoolDialog";
import AddToSetDialog from "@/pages/posts/show/AddToSetDialog";
import ApprovalToolbar from "@/pages/posts/show/ApprovalToolbar";
import BlacklistedImage from "@/pages/posts/show/BlacklistedImage";
import DeleteWithReasonDialog from "@/pages/posts/show/DeleteWithReasonDialog";
import DetailedRejectionDialog from "@/pages/posts/show/DetailedRejectionDialog";
import EditTab from "@/pages/posts/show/EditTab";
import MobileTabs from "@/pages/posts/show/MobileTabs";
import Navigation from "@/pages/posts/show/Navigation";
import Note from "@/pages/posts/show/notes";
import PostActions from "@/pages/posts/show/PostActions";
import RelationshipPreview from "@/pages/posts/show/RelationshipPreview";
import ReownerDialog from "@/pages/posts/show/ReownerDialog";
import PostsShowToolbar from "@/pages/posts/show/toolbar";
import Recommended from "@/pages/posts/show/Recommended";
import RemoveFromSetLinks from "@/pages/posts/show/RemoveFromSetLinks";
import TagEditor from "@/pages/posts/show/TagEditor";
import PostResizer from "@/pages/posts/show/Resizer";
import SwipeGestureHandler from "@/pages/posts/show/SwipeGestureHandler";
import PostVideo from "@/pages/posts/show/Video";


import "@/pages/post_flags/post_flags"; // We only need expandable notes from here

State.onReady(() => {
  void BlacklistedImage.instance;
  void MobileTabs.instance;
  void Note.instance;
  void PostsShowToolbar.instance;
  void TagEditor.instance;
  void PostResizer.instance;
  void SwipeGestureHandler.instance;
  void PostVideo.instance;

  void AddToPoolDialog.instance;
  void AddToSetDialog.instance;
  void DetailedRejectionDialog.instance;
  void DeleteWithReasonDialog.instance;
  void ApprovalToolbar.instance;
  void Recommended.instance;
  void RemoveFromSetLinks.instance;
  void PostActions.instance;
  void Navigation.instance;
  void RelationshipPreview.instance;
  void EditTab.instance;
  void ReownerDialog.instance;

  ModuleRegistry.register("v_posts_show", { Note, CurrentPost, PostResizer: PostResizer.instance });
});
