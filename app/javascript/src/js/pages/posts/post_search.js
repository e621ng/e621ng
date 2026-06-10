import LStorage from "@/utility/Storage";
import Page from "@/utility/Page";
import Offclick from "@/utility/Offclick";
import SVGIcon from "@/utility/SVGIcon";

const PostSearch = {};

// asc: true = supports order:value_asc; false = single direction only
PostSearch.order_values = {
  id: { label: "ID", icon: "hash", asc: true },
  score: { label: "Score", icon: "trending_up", asc: true },
  favcount: { label: "Favorites", icon: "star", asc: true },
  created: { label: "Date", icon: "clock_fading", asc: true },
  updated: { label: "Updated", icon: "clock_fading", asc: true },
  change: { label: "Change", icon: "reset", asc: true },
  comment: { label: "Comment", icon: "message_square", asc: true },
  comment_count: { label: "Comment", icon: "message_square", asc: true },
  comment_bumped: { label: "Comment", icon: "message_square", asc: true },
  mpixels: { label: "Resolution", icon: "fullscreen", asc: true },
  filesize: { label: "Filesize", icon: "file", asc: true },
  duration: { label: "Duration", icon: "clock_fading", asc: true },
  tagcount: { label: "Tags", icon: "tags", asc: true },
  general_tags: { label: "Tags", icon: "tags", asc: true },
  artist_tags: { label: "Tags", icon: "tags", asc: true },
  contributor_tags: { label: "Tags", icon: "tags", asc: true },
  copyright_tags: { label: "Tags", icon: "tags", asc: true },
  character_tags: { label: "Tags", icon: "tags", asc: true },
  species_tags: { label: "Tags", icon: "tags", asc: true },
  invalid_tags: { label: "Tags", icon: "tags", asc: true },
  meta_tags: { label: "Tags", icon: "tags", asc: true },
  lore_tags: { label: "Tags", icon: "tags", asc: true },
  md5: { label: "MD5", icon: "hash", asc: true },
  note: { label: "Notes", icon: "notepad", asc: true },
  random: { label: "Random", icon: "shuffle", asc: false },
  hot: { label: "Hot", icon: "flame", asc: false },
  landscape: { label: "Landscape", icon: "images", asc: false },
  portrait: { label: "Portrait", icon: "images", asc: false },
};

PostSearch.SUPPORTED_ORDER_VALUES = Object.entries(PostSearch.order_values)
  .flatMap(([key, val]) => (val.asc ? [key, key + "_asc"] : [key]));
PostSearch.order_custom = "__custom";
PostSearch.order_desc = "desc";
PostSearch.order_asc = "asc";

PostSearch.ratings = ["s", "q", "e"];
PostSearch.rating_all = PostSearch.ratings.join("");
PostSearch.rating_token = {
  sqe: "",
  sq: "-rating:e",
  qe: "-rating:s",
  se: "-rating:q",
  s: "rating:s",
  q: "rating:q",
  e: "rating:e",
};

PostSearch.initialize_input = function ($form) {
  const $textarea = $form.find("textarea[name='tags']").first();
  if (!$textarea.length) return;
  const element = $textarea[0];

  // Adjust the number of rows based on input length
  $textarea
    .on("input", recalculateInputHeight)
    .on("keypress", function (event) {
      if (event.which !== 13 || event.shiftKey) return;
      event.preventDefault();
      $textarea.closest("form").trigger("submit");
    });

  $(window).on("resize", recalculateInputHeight);

  // Reset default height
  recalculateInputHeight();

  function recalculateInputHeight () {
    $textarea.css("height", 0);
    $textarea.css("height", element.scrollHeight + "px");
  }
};

PostSearch.initialize_advanced_search_details = function ($section) {
  const $details = $section.find("details.post-advanced-search").first();
  if (!$details.length) return;

  $details.prop("open", LStorage.Posts.AdvancedSearchOpen);
  $details.on("toggle", (event) => {
    LStorage.Posts.AdvancedSearchOpen = event.currentTarget.open;
  });
};

PostSearch.initialize_advanced_search = function ($section) {
  const $textarea = $section.find("textarea[name=tags]").first();
  const $controls = $("#advanced-search-container").length
    ? $("#advanced-search-container")
    : $section;
  const $sortInputs = $controls.find("[name='advanced-search-sort']");
  const $inpool = $controls.find("[data-advanced-search=inpool]").first();
  const $ratings = $controls.find("[name='advanced-search-rating']");

  if (!$textarea.length) return;

  const sort_custom = "advanced-search-sort-custom";

  const removeSortCustom = () => {
    $controls.find(`#${sort_custom}, label[for='${sort_custom}']`).remove();
  };

  const addSortExtra = (label, iconName) => {
    const svgEl = iconName ? SVGIcon.render(iconName, 1) : null;
    const icon = svgEl ? svgEl.outerHTML : "";
    $sortInputs.first().closest(".ssc-body").append(
      `<input type="radio" id="${sort_custom}" name="advanced-search-sort" value="${PostSearch.order_custom}">`
      + `<label for="${sort_custom}">${icon}${label}</label>`,
    );
  };

  const addAscBtn = (inputId, direction) => {
    const $label = $controls.find(`label[for='${inputId}']`);
    const $btn = $("<button>")
      .attr("type", "button")
      .addClass("sort-asc-btn")
      .toggleClass("active", direction === PostSearch.order_asc)
      .text("-");
    $label.append($btn);
  };

  const getSortValue = () => $controls.find("[name='advanced-search-sort']:checked").val() || "";
  const setSortValue = (value, direction) => {
    $controls.find("[name='advanced-search-sort']").prop("checked", false);
    $controls.find(".sort-asc-btn").remove();
    if (value === PostSearch.order_custom) {
      removeSortCustom();
      addSortExtra("Custom", "pencil");
      $controls.find(`#${sort_custom}`).prop("checked", true);
    } else {
      removeSortCustom();
      const $found = $sortInputs.filter(`[value="${value}"]`);
      if ($found.length) {
        $found.prop("checked", true);
        if (PostSearch.order_values[value]?.asc) addAscBtn($found.attr("id"), direction);
      } else if (value) {
        const entry = PostSearch.order_values[value];
        addSortExtra(entry ? entry.label : "Custom", entry ? entry.icon : "pencil");
        $controls.find(`#${sort_custom}`).prop("checked", true);
        if (entry?.asc) addAscBtn(sort_custom, direction);
      }
    }
  };

  const inpool_states = ["unset", "yes", "no"];
  const inpool_values = { unset: "", yes: "true", no: "false" };
  const inpool_state_map = { "": "unset", "true": "yes", "false": "no" };
  const getInpool = () => $("[data-advanced-search=inpool]").first();
  const setInpoolState = (value) => {
    const state = inpool_state_map[value] || "unset";
    getInpool().attr("data-state", state).attr("aria-label", `In pool: ${state}`);
  };

  let ratingUpdateInProgress = false;

  const syncRatingControls = function (ratings) {
    if (!$ratings.length || ratingUpdateInProgress) return;
    const selectedRatings = ratings || PostSearch.rating_all;
    $ratings.each((index, element) => {
      const $rating = $(element);
      $rating.prop("checked", selectedRatings.includes($rating.val() + ""));
    });
  };

  const syncControls = function () {
    const state = PostSearch.advanced_search_state($textarea.val() + "");
    if ($sortInputs.length) setSortValue(state.order, state.direction);
    if ($inpool.length) setInpoolState(state.inpool);
    syncRatingControls(state.ratings);
  };

  const updateOrder = function () {
    $textarea.val(PostSearch.replace_order_metatags($textarea.val() + "", getSortValue(), PostSearch.order_desc));
    $textarea.trigger("input");
    syncControls();
  };

  const toggleAsc = function () {
    const state = PostSearch.advanced_search_state($textarea.val() + "");
    const newDirection = state.direction === PostSearch.order_asc ? PostSearch.order_desc : PostSearch.order_asc;
    $textarea.val(PostSearch.replace_order_metatags($textarea.val() + "", state.order, newDirection));
    $textarea.trigger("input");
    syncControls();
  };

  const updateInpool = function (event) {
    const $el = $(event.currentTarget);
    const spanIndex = $el.find(".sto-tri").toArray().indexOf(event.target);
    let next;
    if (spanIndex >= 0) {
      next = inpool_states[spanIndex];
    } else {
      const cur = inpool_states.indexOf($el.attr("data-state"));
      next = inpool_states[(cur + 1) % inpool_states.length];
    }
    $el.attr("data-state", next).attr("aria-label", `In pool: ${next}`);
    $textarea.val(PostSearch.replace_inpool_metatags($textarea.val() + "", inpool_values[next]));
    $textarea.trigger("input");
    syncControls();
  };

  const updateRatings = function () {
    const checkedRatings = PostSearch.checked_rating_values($ratings);
    ratingUpdateInProgress = true;
    $textarea.val(PostSearch.replace_rating_metatags($textarea.val() + "", checkedRatings));
    $textarea.trigger("input");
    syncControls();
    ratingUpdateInProgress = false;
  };

  if ($sortInputs.length) $textarea.closest("form").on("submit", () => $sortInputs.prop("disabled", true));

  $textarea.on("input", syncControls);
  $controls.on("change", "[name='advanced-search-sort']", updateOrder);
  $controls.on("click", ".sort-asc-btn", (event) => {
    event.preventDefault();
    event.stopPropagation();
    toggleAsc();
  });
  $(document).on("click", "[data-advanced-search=inpool]", updateInpool);
  $ratings.on("change", updateRatings);

  syncControls();
};

PostSearch.advanced_search_state = function (query) {
  const state = {
    order: "",
    direction: PostSearch.order_desc,
    inpool: "",
    ratings: PostSearch.rating_all,
  };

  for (const token of PostSearch.scan_top_level_tokens(query)) {
    const order = PostSearch.parse_order_token(token.text);
    if (order) {
      state.order = order.value;
      state.direction = order.direction;
    }

    const inpool = PostSearch.parse_inpool_token(token.text);
    if (inpool !== null) state.inpool = inpool;

    const rating = PostSearch.parse_rating_token(token.text);
    if (rating) state.ratings = PostSearch.apply_rating_token(state.ratings, rating);
  }

  if (!state.ratings) state.ratings = PostSearch.rating_all;
  return state;
};

PostSearch.scan_top_level_tokens = function (query) {
  const tokens = [];
  let depth = 0;
  let quoted = false;
  let start = null;
  let startDepth = 0;

  for (let i = 0; i <= query.length; i++) {
    const char = query[i] || "";
    const atEnd = i === query.length;
    const whitespace = atEnd || /\s/.test(char);

    if (start === null && !atEnd && !whitespace) {
      start = i;
      startDepth = depth;
    }

    if (whitespace && !quoted && start !== null) {
      const text = query.slice(start, i);
      if (startDepth === 0) tokens.push({ text, start, end: i });
      start = null;
    }

    if (atEnd) continue;
    if (char === "\"") quoted = !quoted;
    if (quoted) continue;

    if (char === "(") depth += 1;
    if (char === ")" && depth > 0) depth -= 1;
  }

  return tokens;
};

PostSearch.parse_order_token = function (text) {
  const match = text.match(/^(-?)order:(.+)$/i);
  if (!match) return null;

  let value = PostSearch.unquote_metatag_value(match[2]).toLowerCase();
  const negated = match[1] === "-";

  if (PostSearch.order_values[value] && !PostSearch.order_values[value].asc) {
    return {
      value: negated ? PostSearch.order_custom : value,
      direction: PostSearch.order_desc,
    };
  }

  if (value.endsWith("_desc")) value = value.slice(0, -5);

  const root = value.replace(/_asc$/, "");
  if (!PostSearch.order_values[root]?.asc) {
    return {
      value: PostSearch.order_custom,
      direction: PostSearch.order_desc,
    };
  }

  let direction = value.endsWith("_asc") ? PostSearch.order_asc : PostSearch.order_desc;

  if (negated) {
    direction = direction === PostSearch.order_asc ? PostSearch.order_desc : PostSearch.order_asc;
  }

  return {
    value: root,
    direction,
  };
};

PostSearch.parse_inpool_token = function (text) {
  const match = text.match(/^inpool:(true|false)$/i);
  if (!match) return null;
  return match[1].toLowerCase();
};

PostSearch.parse_rating_token = function (text) {
  const match = text.match(/^(-?)rating:(.+)$/i);
  if (!match) return null;

  const value = PostSearch.unquote_metatag_value(match[2]).toLowerCase()[0];
  if (!PostSearch.ratings.includes(value)) return null;

  return {
    value,
    negated: match[1] === "-",
  };
};

PostSearch.unquote_metatag_value = function (value) {
  if (value.startsWith("\"") && value.endsWith("\"")) return value.slice(1, -1);
  return value;
};

PostSearch.apply_rating_token = function (ratings, rating) {
  if (rating.negated) return ratings.replace(rating.value, "");
  return rating.value;
};

PostSearch.checked_rating_values = function ($ratings) {
  return $ratings
    .filter(":checked")
    .map((index, element) => element.value)
    .get()
    .sort((a, b) => PostSearch.ratings.indexOf(a) - PostSearch.ratings.indexOf(b));
};


PostSearch.order_has_direction = function (value) {
  return !!PostSearch.order_values[value]?.asc;
};

PostSearch.order_metatag_value = function (value, direction) {
  if (!value) return "";
  if (value === PostSearch.order_custom) return PostSearch.order_custom;
  const entry = PostSearch.order_values[value];
  if (!entry) return PostSearch.order_custom;
  if (!entry.asc) return value;
  return direction === PostSearch.order_asc ? value + "_asc" : value;
};

PostSearch.replace_order_metatags = function (query, value, direction) {
  const orderValue = PostSearch.order_metatag_value(value, direction);
  if (orderValue === PostSearch.order_custom) return query;

  const newToken = orderValue && PostSearch.SUPPORTED_ORDER_VALUES.includes(orderValue)
    ? "order:" + orderValue
    : "";

  return PostSearch.replace_top_level_metatags(query, (token) => !!PostSearch.parse_order_token(token), newToken);
};

PostSearch.replace_inpool_metatags = function (query, value) {
  const newToken = value ? "inpool:" + value : "";
  return PostSearch.replace_top_level_metatags(query, (token) => PostSearch.parse_inpool_token(token) !== null, newToken);
};

PostSearch.rating_metatag_token = function (ratings) {
  return PostSearch.rating_token[ratings.join("")] || "";
};

PostSearch.replace_rating_metatags = function (query, ratings) {
  return PostSearch.replace_top_level_metatags(
    query,
    (token) => PostSearch.parse_rating_token(token) !== null,
    PostSearch.rating_metatag_token(ratings),
  );
};

PostSearch.replace_top_level_metatags = function (query, matcher, newToken) {
  const tokens = PostSearch.scan_top_level_tokens(query).filter(token => matcher(token.text));
  let result = query;

  for (const token of tokens.reverse()) {
    result = PostSearch.remove_token_range(result, token.start, token.end);
  }

  result = result.trim();
  if (newToken) result = [result, newToken].filter(n => n).join(" ");

  return result;
};

PostSearch.remove_token_range = function (query, start, end) {
  let removeStart = start;
  let removeEnd = end;

  while (removeEnd < query.length && /\s/.test(query[removeEnd])) removeEnd += 1;
  if (removeEnd === end) {
    while (removeStart > 0 && /\s/.test(query[removeStart - 1])) removeStart -= 1;
  }

  return query.slice(0, removeStart) + query.slice(removeEnd);
};

PostSearch.initialize_wiki_preview = function ($preview) {
  let visible = LStorage.Posts.WikiExcerpt;
  if (visible == 2) return; // hidden
  if (visible == 1) $preview.addClass("open");
  $preview.removeClass("hidden");

  window.setTimeout(() => { // Disable the rollout on first load
    $preview.removeClass("loading");
  }, 250);

  // Toggle the excerpt box open / closed
  $($preview.find("h3.wiki-excerpt-toggle")).on("click", (event) => {
    event.preventDefault();

    visible = !visible;
    $preview.toggleClass("open", visible);
    LStorage.Posts.WikiExcerpt = Number(visible);

    return false;
  });

  // Hide the excerpt box entirely
  $preview.find("button.wiki-excerpt-dismiss").on("click", (event) => {
    event.preventDefault();

    $preview.addClass("hidden");
    LStorage.Posts.WikiExcerpt = 2;

    return false;
  });
};

PostSearch.initialize_controls = function () {
  // Advanced search panel
  const advOffclickHandler = Offclick.register("#advanced-search-open", "#advanced-search-container", () => {
    // CLOSE ADVANCED OPTIONS
    // advSearch.removeClass("active");
    // advSearchBtn.removeClass("active");
    // LStorage.Posts.AdvancedSearchOpen = false;
    // CLOSE ADVANCED OPTIONS
  });

  const advSearch = $("#advanced-search-container");
  const advSearchBtn = $("#advanced-search-open").on("click", () => {
    const state = advOffclickHandler.disabled;
    advSearch.toggleClass("active", state);
    advSearchBtn.toggleClass("active", state);
    LStorage.Posts.AdvancedSearchOpen = state;
    advOffclickHandler.disabled = !state;
  });

  advSearch.toggleClass("active", !!LStorage.Posts.AdvancedSearchOpen);
  advSearchBtn.toggleClass("active", !!LStorage.Posts.AdvancedSearchOpen);
  if (LStorage.Posts.AdvancedSearchOpen) advOffclickHandler.disabled = false;

  advSearch.find("#advanced-search-close").on("click", (event) => {
    event.preventDefault();
    advSearch.removeClass("active");
    advSearchBtn.removeClass("active");
    LStorage.Posts.AdvancedSearchOpen = false;
    advOffclickHandler.disabled = true;
  });

  // Regular buttons
  let fullscreen = LStorage.Posts.Fullscreen;
  const $toggleBtn = $("#toggle-fullscreen");
  const iconHide = SVGIcon.render("sidebar_hide").outerHTML;
  const iconShow = SVGIcon.render("sidebar_show").outerHTML;

  function setFullscreenIcon () {
    $toggleBtn.html(fullscreen ? iconShow : iconHide);
    $("body").attr("data-st-fullscreen", fullscreen);
  }

  setFullscreenIcon();
  $toggleBtn.on("click", () => {
    fullscreen = !fullscreen;
    LStorage.Posts.Fullscreen = fullscreen;
    setFullscreenIcon();
  });

  // Menu open / close
  const offclickHandler = Offclick.register("#layout-settings-open", "#layout-settings-container", () => {
    menu.removeClass("active");
    menuButton.removeClass("active");
  });

  const menu = $("#layout-settings-container");
  const menuButton = $("#layout-settings-open").on("click", () => {
    const state = offclickHandler.disabled;
    menu.toggleClass("active", state);
    menuButton.toggleClass("active", state);
    offclickHandler.disabled = !state;
  });

  menu.find("#layout-settings-close").on("click", (event) => {
    event.preventDefault();
    menu.removeClass("active");
    menuButton.removeClass("active");
    offclickHandler.disabled = true;
  });

  // Menu toggles
  $("#ssc-image-contain")
    .prop("checked", LStorage.Posts.Contain)
    .on("change", (event) => {
      LStorage.Posts.Contain = event.target.checked;
      $("body").attr("data-st-contain", event.target.checked);
    });

  $("input[type='radio'][name='ssc-card-size']")
    .on("change", (event) => {
      LStorage.Posts.Size = event.target.value;
      $("body").attr("data-st-size", event.target.value);
    });
  $("input[type='radio'][name='ssc-card-size'][value='" + LStorage.Posts.Size + "']")
    .prop("checked", true);

  function updateHoverTextNodes () {
    $("a[data-hover-text]").attr("title", function () {
      const source = $(this).data("hover-text");
      if (!source) return "";

      switch (LStorage.Posts.HoverText) {
        case "none":
          return "";
        case "short":
          return source.split("\n\n")[0];
        case "long":
        default:
          return source;
      }
    });
  }
  $("input[type='radio'][name='ssc-hover-text']")
    .on("change", (event) => {
      LStorage.Posts.HoverText = event.target.value;
      updateHoverTextNodes();
    });
  $("input[type='radio'][name='ssc-hover-text'][value='" + LStorage.Posts.HoverText + "']")
    .prop("checked", true);
  updateHoverTextNodes();

  $("#ssc-sticky-searchbar")
    .prop("checked", LStorage.Posts.StickySearch)
    .on("change", (event) => {
      LStorage.Posts.StickySearch = event.target.checked;
      $("body").attr("data-st-stickysearch", event.target.checked);
    });
};

$(() => {

  $(".post-search").each((index, element) => {
    const $element = $(element);
    PostSearch.initialize_input($element);
    PostSearch.initialize_advanced_search($element);
  });

  if (!Page.matches("posts") && !Page.matches("favorites"))
    return;

  $(".wiki-excerpt").each((index, element) => {
    PostSearch.initialize_wiki_preview($(element));
  });

  PostSearch.initialize_controls();
});

export default PostSearch;
