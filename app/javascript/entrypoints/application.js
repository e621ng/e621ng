/* eslint no-console:0 */

import $ from "jquery";
window.jQuery = $;
window.$ = $;

import Rails from "@rails/ujs";
Rails.start();


import.meta.glob("../src/javascripts/models/**/*.js", { eager: true });
import.meta.glob("../src/javascripts/**/*.js", { eager: true });

// TODO: Remove this global Danbooru object and migrate all code to use ES6 imports instead.
// This mimics the old webpacker output.library behavior for backward compatibility.
import LStorage from "../src/javascripts/utility/storage.js";
import TaskQueue from "../src/javascripts/utility/task_queue.js";
import Hotkeys from "../src/javascripts/hotkeys.js";
import Dialog from "../src/javascripts/utility/dialog.js";
import SVGIcon from "../src/javascripts/utility/svg_icon.js";
import Favorite from "../src/javascripts/models/Favorite.js";
import PostVote from "../src/javascripts/models/PostVote.js";
import User from "../src/javascripts/models/User.js";
import Autocomplete from "../src/javascripts/autocomplete.js";
import Blacklist from "../src/javascripts/blacklists.js";
import Blip from "../src/javascripts/blips.js";
import Comment from "../src/javascripts/comments.js";
import DTextFormatter from "../src/javascripts/dtext_formatter.js";
import FurID from "../src/javascripts/furid.js";
import ModAction from "../src/javascripts/mod_actions.js";
import Note from "../src/javascripts/notes.js";
import Post from "../src/javascripts/posts.js";
import PostDeletion from "../src/javascripts/post_delete.js";
import PostModeMenu from "../src/javascripts/post_mode_menu.js";
import PostReplacement from "../src/javascripts/post_replacement.js";
import PostVersions from "../src/javascripts/post_versions.js";
import Replacer from "../src/javascripts/replacer.js";
import StaffNote from "../src/javascripts/staff_notes.js";
import Utility from "../src/javascripts/utility.js";
import TagRelationships from "../src/javascripts/tag_relationships.js";
import Takedown from "../src/javascripts/takedowns.js";
import Theme from "../src/javascripts/themes.js";
import Thumbnails from "../src/javascripts/thumbnails.js";
import Uploader from "../src/javascripts/uploader.js";
import VoteManager from "../src/javascripts/vote_manager.js";

function inError (msg) {
  $(window).trigger("danbooru:error", msg);
}

function inNotice (msg) {
  $(window).trigger("danbooru:notice", msg);
}

window.Danbooru = {
  LStorage,
  TaskQueue,
  Hotkeys,
  Dialog,
  SVGIcon,
  Favorite,
  PostVote,
  User,
  Autocomplete,
  Blacklist,
  Blip,
  Comment,
  DTextFormatter,
  FurID,
  ModAction,
  Note,
  Post,
  PostDeletion,
  PostModeMenu,
  PostReplacement,
  PostVersions,
  Replacer,
  StaffNote,
  Utility,
  TagRelationships,
  Takedown,
  Theme,
  Thumbnails,
  Uploader,
  VoteManager,
  error: inError,
  notice: inNotice,
};
