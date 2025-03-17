import Filter from "./models/Filter";
import PostCache from "./models/PostCache";
import User from "./models/User";
import Utility from "./utility";
import Page from "./utility/page";
import LStorage from "./utility/storage";

let Blacklist = {};

Blacklist.isAnonymous = false;
Blacklist.isPostsShow = false;
Blacklist.filters = {};

Blacklist.hiddenPosts = new Set();
Blacklist.matchedPosts = new Set();

Blacklist.ui = [];

/** Import the anonymous blacklist from the LocalStorage */
Blacklist.init_anonymous_blacklist = function () {
  let metaTag = $("meta[name=blacklisted-tags]");
  if (metaTag.length == 0)
    metaTag = $("<meta>")
      .attr({
        name: "blacklisted-tags",
        content: "[]",
      })
      .appendTo("head");

  if ($("body").data("user-is-anonymous")) {
    Blacklist.isAnonymous = true;
    metaTag.attr("content", LStorage.Blacklist.AnonymousBlacklist);
  }
};

/** Set up the modal dialogue with the blacklist editor */
Blacklist.init_blacklist_editor = function () {
  let windowWidth = $(window).width(),
    windowHeight = $(window).height();
  $("#blacklist-edit-dialog").dialog({
    autoOpen: false,
    width: windowWidth > 400 ? 400 : windowWidth,
    height: windowHeight > 400 ? 400 : windowHeight,
  });

  $("#blacklist-cancel").on("click", function () {
    $("#blacklist-edit-dialog").dialog("close");
  });

  $("#blacklist-save").on("click", function () {
    const blacklist_content = $("#blacklist-edit").val();
    const blacklist_json = blacklist_content.split(/\n\r?/);
    User.blacklist.tags = blacklist_json;
    User.saveBlacklist();
  });

  $("#blacklist-edit-link").on("click", function (event) {
    event.preventDefault();
    let entries = JSON.parse(Utility.meta("blacklisted-tags") || "[]");
    $("#blacklist-edit").val(entries.join("\n"));
    $("#blacklist-edit-dialog").dialog("open");
  });
};

/** Reveals the blacklisted post without disabling any filters */
Blacklist.init_reveal_on_click = function () {
  if (!$("#c-posts #a-show").length) return;
  $("#image-container").on("click", (event) => {
    $(event.currentTarget).removeClass("blacklisted");

    $("#note-container").css("visibility", "visible");
    Danbooru.Note.Box.scale_all();
  });
};

/** Import the blacklist from the meta tag */
Blacklist.regenerate_filters = function () {
  Blacklist.filters = {};

  // Attempt to create filters from text
  for (let entry of User.blacklist.tags) {
    const line = Filter.create(entry);
    if (line) Blacklist.filters[line.text] = line;
  }

  // Clear any FilterState entries that don't have a matching filter
  const keys = Object.keys(Blacklist.filters);
  for (const filterState of LStorage.Blacklist.FilterState) {
    if (keys.includes(filterState)) continue;
    LStorage.Blacklist.FilterState.delete(filterState);
  }
};

/** Hides all comments created by blacklisted users */
Blacklist.init_comment_blacklist = function () {
  if (Utility.meta("blacklist-users") !== "true") return;

  // This is extraordinarily silly
  // We need a proper user ignoring system
  for (const filter of Object.values(Blacklist.filters)) {

    // Only the first token is accepted
    // If the user is trying something wackier, that's their fault
    if (!filter.tokens.length) continue;
    const token = filter.tokens[0];

    switch (token.type) {
      case "user": {
        if (token.value.startsWith("!")) {
          $(`article[data-creator-id="${token.value.slice(1)}"]`).hide();
          continue;
        }
        // falls through
      }
      case "username": {
        $(`article[data-creator="${token.value}"]`).hide();
        continue;
      }
      case "userid": {
        $(`article[data-creator-id="${token.value}"]`).hide();
        continue;
      }
    }
  }
};

/** Build the sidebar and inline blacklist toggles */
Blacklist.init_blacklist_toggles = function () {
  if (Blacklist.ui.length) return;

  $(".blacklist-ui").each((index, element) => {
    Blacklist.ui.push(new BlacklistUI($(element)));
  });
};

Blacklist.init_quick_blacklist = function () {
  for (const one of User.blacklist.tags) {
    if (one.includes(" ")) continue;
    $(`li.tag-list-item[data-name='${one}`).addClass("blacklisted");
  }

  $(".tag-list-actions button").on("click", (event) => {
    const target = $(event.currentTarget);
    const tag = target.data("tag");
    if (!tag) return;

    if (User.blacklist.tags.includes(tag)) {
      User.removeBlacklistedTag(tag);
      target.parents(".tag-list-item").removeClass("blacklisted");
    } else {
      User.addBlacklistedTag(tag);
      target.parents(".tag-list-item").addClass("blacklisted");
    }
  });
};

/**
 * Register posts in the system, and calculate which filters apply to them
 * @param {JQuery<HTMLElement> | JQuery<HTMLElement>[]} $posts Posts to register
 */
Blacklist.add_posts = function ($posts) {
  PostCache.register($posts);

  for (const filter of Object.values(Blacklist.filters))
    filter.update($posts);
};

/**
 * Recalculate hidden posts based on the current filters.
 * Also applies or removed `blacklist` class wherever necessary.
 */
Blacklist.update_visibility = function () {
  let oldPosts = [...this.hiddenPosts],
    newPosts = [];

  // Tally up the new blacklisted posts
  for (const filter of Object.values(Blacklist.filters)) {
    if (!filter.enabled) continue;
    newPosts = newPosts.concat(Array.from(filter.matchIDs));
  }

  // Calculate diffs
  // TODO I feel like this could be optimized.
  this.hiddenPosts = new Set(newPosts.filter(n => n));
  let added = [...this.hiddenPosts].filter((n) => !oldPosts.includes(n)),
    removed = oldPosts.filter((n) => !this.hiddenPosts.has(n));

  // Update the UI
  for (const ui of Blacklist.ui) ui.rebuildFilters();

  // Apply / remove classes
  // TODO: Cache the post elements to avoid repeat lookups
  for (const postID of added)
    PostCache.apply(postID, ($element) => {
      $element.addClass("blacklisted").trigger("blk:hide");
    });
  for (const postID of removed)
    PostCache.apply(postID, ($element) => {
      $element.removeClass("blacklisted").trigger("blk:show");
    });

  // Toggle notes on the posts#show page
  if (!Blacklist.isPostsShow) return;

  const container = $("#image-container");
  if (container.hasClass("blacklisted")) {
    $("#note-container").css("visibility", "hidden");
  } else {
    $("#note-container").css("visibility", "visible");
    Danbooru.Note.Box.scale_all();
  }
};

/**
 * Adds a `filter-matches` class to any thumbnails that match any of the filters,
 * including disabled ones. Only needs to run after new posts get added to the page.
 */
Blacklist.update_styles = function () {
  let allPosts = [];
  for (const filter of Object.values(Blacklist.filters))
    allPosts = allPosts.concat(Array.from(filter.matchIDs));
  Blacklist.matchedPosts = new Set(allPosts);

  $(".filter-matches").removeClass("filter-matches");
  for (const postID of Blacklist.matchedPosts)
    PostCache.apply(postID, ($element) => {
      $element.addClass("filter-matches");
    });
};

$(() => {
  Blacklist.isPostsShow = $("#image-container").length > 0;

  Blacklist.init_anonymous_blacklist();
  Blacklist.init_blacklist_editor();
  Blacklist.init_reveal_on_click();

  Blacklist.regenerate_filters();
  Blacklist.add_posts($(".blacklistable"));
  Blacklist.update_styles();
  Blacklist.update_visibility();
  $("#blacklisted-hider").remove();

  Blacklist.init_comment_blacklist();
  Blacklist.init_blacklist_toggles();
  Blacklist.init_quick_blacklist();

  // Pause videos when blacklisting
  // This seems extraordinarily uncommon, so it's here
  // just for feature parity with the old blacklist.
  if (!Page.matches("posts", "show")) return;
  let container = $("#image-container[data-file-ext='webm']").on("blk:hide", () => {
    const video = container.find("video");
    if (!video.length) return;
    video[0].pause();
  });
});

/**
 * Represents the list of toggles for the blacklist filters.
 * Could be either in a sidebar or inline formats.
 */
class BlacklistUI {
  /**
   * Constructor.
   * Should only be run on `.blacklist-ui` elements.
   * @param {JQuery<HTMLDivElement>} $element
   */
  constructor ($element) {
    this.$element = $element;
    this.$counter = $element.find(".blacklisted-count");

    this.post = parseInt($element.attr("post"));
    this.hasPost = !Number.isNaN(this.post);

    // Collapsable header
    $element
      .attr("collapsed", LStorage.Blacklist.Collapsed)
      .find(".blacklist-header")
      .on("click", () => {
        const newState = this.$element.attr("collapsed") !== "true";
        this.$element.attr("collapsed", newState);
        LStorage.Blacklist.Collapsed = newState;
      });

    // Toggle All switch
    this.$toggle = $element
      .find(".blacklist-toggle-all")
      .text("Disable All Filters")
      .on("click", () => {
        if (this.$toggle.attr("is-enabling") == "true") {
          for (const filter of Object.values(Blacklist.filters))
            filter._enabled = true;
          LStorage.Blacklist.FilterState.clear();
        } else {
          const filterList = new Set();
          for (const filter of Object.values(Blacklist.filters)) {
            filter._enabled = false;
            filterList.add(filter.text);
          }
          LStorage.Blacklist.FilterState = filterList;
        }

        for (const element of Blacklist.ui) element.rebuildFilters();
        Blacklist.update_visibility();
      });

    // Filters
    this.$container = $($element.find(".blacklist-filters"));
    this.rebuildFilters();
  }

  /**
   * Deletes and re-creates the filter list.
   * Done automatically every time a filter gets turned on or off,
   * so all instances are in sync no matter what.
   */
  rebuildFilters () {
    this.$container.html("");

    let activeFilters = 0,
      inactiveFilters = 0;
    for (const [name, filter] of Object.entries(Blacklist.filters)) {
      if (filter.matchIDs.size == 0) continue;

      // Special case for the posts/show page sidebar
      if (this.hasPost && !filter.matchIDs.has(this.post))
        continue;

      activeFilters++;
      if (!filter.enabled) inactiveFilters++;

      const entry = $("<li>")
        .attr("enabled", filter.enabled)
        .on("click", () => {
          // Actual toggling done elsewhere
          filter.enabled = !filter.enabled;
        })
        .appendTo(this.$container);

      const link = $("<a>")
        .attr("href", "/posts?tags=" + encodeURIComponent(name))
        .html(name
          .replace(/_/g, "&#8203;_") // Allow tags to linebreak on underscores
          .replace(/ -/, " &#8209;"), // Prevent linebreaking on negated tags
        )
        .on("click", (event) => {
          event.preventDefault();
          // Link is disabled, but could still be right-clicked
        })
        .appendTo(entry);

      $("<span>").text(filter.matchIDs.size).appendTo(link);
    }

    // Update the total blacklist size
    this.$element.attr("filters", activeFilters);
    this.$counter.text("(" + Blacklist.hiddenPosts.size + ")");

    // Change the toggle state accordingly
    this.$toggle
      .text(inactiveFilters ? "Enable All Filters" : "Disable All Filters")
      .attr("is-enabling", inactiveFilters > 0);
  }
}

export default Blacklist;
