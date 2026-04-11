/* eslint no-console:0 */


// ===== Old glob imports ===== 
// import.meta.glob("../src/javascripts/models/**/*.js", { eager: true });
// import.meta.glob("../src/javascripts/**/*.js", { eager: true });


// ===== Manual imports =====
import "../src/javascripts/forum_posts.js";
import "../src/javascripts/forum_topics.js";
import "../src/javascripts/post_diff.js";
import "../src/javascripts/post_flags.js";
import "../src/javascripts/post_search.js";
import "../src/javascripts/post_sets.js";
import "../src/javascripts/pages/search_trends/track/search_trends_track.js";
import "../src/javascripts/tag_script.js";
import "../src/javascripts/takedown_editor.js";
import "../src/javascripts/ticket_report_form.js";
// import "../src/javascripts/user_warning.js";
import "../src/javascripts/models/Filter.js";
import "../src/javascripts/models/PostCache.js";
import "../src/javascripts/views/StaticShortcuts.js";


// ===== Global Danbooru object =====
// TODO: Remove this global Danbooru object and migrate all code to use ES6 imports instead.
// This mimics the old webpacker output.library behavior for backward compatibility.
import ModAction from "../src/javascripts/mod_actions.js";
import PostModeMenu from "../src/javascripts/post_mode_menu.js";
import PostVersions from "../src/javascripts/post_versions.js";
import StaffNote from "../src/javascripts/staff_notes.js";
import TagRelationships from "../src/javascripts/tag_relationships.js";
import Takedown from "../src/javascripts/takedowns.js";
import VoteManager from "../src/javascripts/vote_manager.js";


/*
window.E621 = {
  LStorage,
  Settings,
  TaskQueue,
  Dialog,
  SVGIcon,
  Favorite,
  PostVote,
  User,
  Comment,
  DTextFormatter,
  ModAction,
  Note,
  Post,
  PostDeletion,
  PostModeMenu,
  PostReplacement,
  PostVersions,
  StaffNote,
  Utility,
  TagRelationships,
  Takedown,
  Theme,
  VoteManager,
  error: inError,
  notice: inNotice,
};

// We will eventually want to remove the Danbooru object, and use E621 instead.
window.Danbooru = window.E621;
*/
