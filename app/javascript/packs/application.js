/* eslint no-console:0 */
/* global require */

function importAll (r) {
  r.keys().forEach(r);
}

export { default as $ } from "jquery";

import Rails from "@rails/ujs";
Rails.start();

require("jquery-ui/ui/widgets/sortable");
require("jquery-ui/ui/widgets/resizable");
require("jquery-ui/themes/base/core.css");
require("jquery-ui/themes/base/sortable.css");
require("jquery-ui/themes/base/resizable.css");
require("jquery-ui/themes/base/theme.css");

require("../src/styles/base.scss");

// Utilities
export { default as LStorage } from "../src/javascripts/utility/storage.js";
export { default as TaskQueue } from "../src/javascripts/utility/task_queue.js";
export { default as Hotkeys } from "../src/javascripts/hotkeys.js";
export { default as Dialog } from "../src/javascripts/utility/dialog.js";

// Models
importAll(require.context("../src/javascripts/models", true, /\.js(\.erb)?$/));
export { default as Favorite } from "../src/javascripts/models/Favorite.js";
export { default as PostVote } from "../src/javascripts/models/PostVote.js";
export { default as User } from "../src/javascripts/models/User.js";

// Old handlers
importAll(require.context("../src/javascripts", true, /\.js(\.erb)?$/));
require.context("../../../public/images", true);

export { default as Autocomplete } from "../src/javascripts/autocomplete.js";
export { default as Blacklist } from "../src/javascripts/blacklists.js";
export { default as Blip } from "../src/javascripts/blips.js";
export { default as Comment } from "../src/javascripts/comments.js";
export { default as DText } from "../src/javascripts/dtext.js";
export { default as FurID } from "../src/javascripts/furid.js";
export { default as ModAction } from "../src/javascripts/mod_actions.js";
export { default as Note } from "../src/javascripts/notes.js";
export { default as Post } from "../src/javascripts/posts.js";
export { default as PostDeletion } from "../src/javascripts/post_delete.js";
export { default as PostModeMenu } from "../src/javascripts/post_mode_menu.js";
export { default as PostReplacement } from "../src/javascripts/post_replacement.js";
export { default as PostVersions } from "../src/javascripts/post_versions.js";
export { default as Replacer } from "../src/javascripts/replacer.js";
export { default as StaffNote } from "../src/javascripts/staff_notes.js";
export { default as Utility } from "../src/javascripts/utility.js";
export { default as TagRelationships } from "../src/javascripts/tag_relationships.js";
export { default as Takedown } from "../src/javascripts/takedowns.js";
export { default as Theme } from "../src/javascripts/themes.js";
export { default as Thumbnails } from "../src/javascripts/thumbnails.js";
export { default as Uploader } from "../src/javascripts/uploader.js";
export { default as VoteManager } from "../src/javascripts/vote_manager.js";

function inError (msg) {
  $(window).trigger("danbooru:error", msg);
}

function inNotice (msg) {
  $(window).trigger("danbooru:notice", msg);
}

export {inError as error, inNotice as notice};
