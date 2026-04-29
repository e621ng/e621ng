import Page from "@/utility/Page";
import SVGIcon from "@/utility/SVGIcon";
import LStorage from "@/utility/storage";
import Blacklist from "@/core/blacklists";
import Analytics from "@/core/analytics";
import Logger from "@/utility/Logger";
import PerformanceTracker from "@/utility/PerformanceTracker";
import Settings from "@/utility/Settings";
import CStorage from "@/utility/StorageC";

const Recommended = {};

Recommended.RESULT_COUNT = 6;
Recommended.SHOW_ENGINE_RESULTS = false;
Recommended.Logger = new Logger("Recommended");
Recommended.allStates = ["artist", "favorites", "tags"];
Recommended.validStates = ["artist"];
Recommended.requestID = 0;

Recommended.remote_actions = ["favorites", "tags"];

Recommended.init = function () {
  if (Recommended.$container.length === 0) return;

  Recommended.SHOW_ENGINE_RESULTS = Settings.Recommender.remote;
  if (Recommended.SHOW_ENGINE_RESULTS)
    Recommended.validStates.push("favorites", "tags");
  const initialAction = Recommended.action;
  Recommended.Logger.log("Loaded", {
    action: initialAction,
    showEngineResults: Recommended.SHOW_ENGINE_RESULTS,
    validStates: Recommended.validStates,
  });


  Recommended.$wrapper.attr("data-action", initialAction);
  Recommended.$wrapper.find("#post-recommendations-tabs button").attr("aria-selected", function () {
    return $(this).data("action") === initialAction ? "true" : "false";
  });
  Recommended.$container.attr("aria-labelledby", `post-recommendations-tab-${initialAction}`);

  // Bootstrap analytics
  if (Analytics.enabled)
    Recommended.$wrapper.one("click", "a", (event) => {
      // Only track the first click to prevent multiple events from being fired if the user clicks
      // multiple times. The links navigate away from the page regardless, so this is acceptable.
      const data = event.currentTarget.dataset;
      if (!data.target) return;
      Analytics.track(Analytics.Event.Recommendation, {
        target: "/posts/" + data.target,
        action: Recommended.action,
      });
    });


  // Detect when the recommendations section is in view.
  let isInitialized = false;
  Recommended.waitUntilReady().then(() => {
    isInitialized = true;
    Recommended.status = "loading";
    Recommended.loadState();
  });

  // Rig tabs
  $("#post-recommendations-tabs").on("click", "button", (event) => {
    if (!isInitialized) return;

    const action = $(event.currentTarget).data("action");
    Recommended.action = action; // validated in the setter
    Recommended.loadState(Recommended.action);
  });

  // Rig the toggle button
  this.$toggle.on("click", () => {
    Recommended.visible = !Recommended.visible;
  });
};

// ============================== //
// ======== Getter Magic ======== //
// ============================== //

Recommended._container = null;
Object.defineProperty(Recommended, "$container", {
  get: function () {
    if (!this._container) this._container = $("#post-recommendations-list");
    return this._container;
  },
});

Recommended._postId = null;
Object.defineProperty(Recommended, "postId", {
  get: function () {
    if (!this._postId) this._postId = this.$wrapper.data("post-id");
    return this._postId;
  },
});

Recommended._wrapper = null;
Object.defineProperty(Recommended, "$wrapper", {
  get: function () {
    if (!Recommended._wrapper) Recommended._wrapper = $("#post-recommendations");
    return Recommended._wrapper;
  },
});

Recommended._toggle = null;
Object.defineProperty(Recommended, "$toggle", {
  get: function () {
    if (!Recommended._toggle) Recommended._toggle = $("#post-recommendations-toggle button");
    return Recommended._toggle;
  },
});

Object.defineProperty(Recommended, "action", {
  get: function () {
    let action = LStorage.Posts.Recommendations;
    if (!Recommended.validStates.includes(action))
      action = Recommended.validStates[0];
    return action;
  },
  set: function (value) {
    if (!Recommended.validStates.includes(value))
      value = Recommended.validStates[0];

    LStorage.Posts.Recommendations = value;
    this.$wrapper.attr("data-action", value);
    this.$wrapper.find("#post-recommendations-tabs button").attr("aria-selected", function () {
      return $(this).data("action") === value ? "true" : "false";
    });
    this.$container.attr("aria-labelledby", `post-recommendations-tab-${value}`);
  },
});

Object.defineProperty(Recommended, "status", {
  get: function () {
    return this.$wrapper.attr("data-status") || "waiting";
  },
  set: function (value) {
    this.$wrapper.attr("data-status", value);
  },
});

Object.defineProperty(Recommended, "visible", {
  get: function () {
    return !CStorage.postRecommenderHidden;
  },
  set: function (value) {
    CStorage.postRecommenderHidden = !value;
    this.$wrapper.attr("data-visible", value ? "true" : "false");
    this.$toggle.attr({
      "aria-expanded": value ? "true" : "false",
      "aria-label": value ? "Hide Recommendations" : "Show Recommendations",
    });
  },
});


// ============================== //
// ====== State Management ====== //
// ============================== //

Recommended.loadState = async function (action = Recommended.action) {
  const requestId = ++Recommended.requestID;
  const requestExpired = function () {
    return requestId !== Recommended.requestID;
  };

  const perf = new PerformanceTracker(`loadState-${action}-${requestId}`);
  const measurePerformance = function () {
    perf.mark("end");

    const output = [ `Loaded in ${perf.measurePretty("start", "end")}` ];
    if (perf.hasMark("data-fetched"))
      output.push(`\n ⤷ Data fetched in ${perf.measurePretty("start", "data-fetched")}`);
    if (perf.hasMark("posts-fetched"))
      output.push(`\n ⤷ Posts fetched in ${perf.measurePretty("data-fetched", "posts-fetched")}`);
    if (perf.hasMark("rendered"))
      output.push(`\n ⤷ Rendered in ${perf.measurePretty("posts-fetched", "rendered")}`);

    Recommended.Logger.log(...output);
    perf.clear();
  };

  Recommended.Logger.log(`Loading state: "${action}" (Req ID: ${requestId})`);
  const $container = Recommended.$container;

  if (!Recommended.validStates.includes(action)) {
    Recommended.action = "artist";
    action = "artist";
  }


  // 1. Render skeleton placeholders
  if (Recommended.status !== "waiting") {
    Recommended.status = "waiting";
    $container.empty();
    for (let i = 0; i < Recommended.RESULT_COUNT; i++)
      $container.append(Recommended.render_placeholder());
  }


  // 2. Fetch recommendations data
  Recommended.status = "loading";
  let data = Recommended.getCachedRecommendations(action);
  if (!data) {
    data = await Recommended.getData(Recommended.postId, action);
    if (!data || !data.results) {
      measurePerformance();
      if (requestExpired()) return;
      Recommended.status = "error";
      $container.html("<p class='error'>Failed to load recommendations.</p>");
      return;
    }

    // Load post data provided by the local recommender
    // Not available for the remote recommender service
    if (data.post_data) {
      Recommended.Logger.log("Found included post data", data.post_data);
      Recommended.setCachedPosts(data.post_data);
      delete data.post_data; // Don't pollute main cache
    }

    // Reformat results for easier access
    const resultsById = {},
      resultsOrder = [];
    for (const result of data.results) {
      resultsById[result.post_id] = result;
      resultsOrder.push(result.post_id);
    }
    data.results = resultsById;
    data.order = resultsOrder;

    // Cache to avoid reloading when switching tabs
    Recommended.setCachedRecommendations(action, data);
    perf.mark("data-fetched");
  } else {
    Recommended.Logger.log("Using cached recommendations:", data);
    perf.mark("data-fetched", "cached");
  }


  // 3. Fetch post data for recommended posts
  let posts = Recommended.getCachedPosts(data.order);
  let missingPostIds = data.order.filter(id => !posts[id]);
  if (missingPostIds.length > 0) {
    const postLookup = await Recommended.getPosts(missingPostIds);
    if (postLookup) {
      for (const post of postLookup) posts[post.id] = post;
      Recommended.setCachedPosts(postLookup);
    } else {
      measurePerformance();
      if (requestExpired()) return;
      Recommended.status = "error";
      $container.html("<p class='error'>Failed to load recommended posts.</p>");
      return;
    }
    perf.mark("posts-fetched");
  } else {
    perf.mark("posts-fetched", "cached");
  }


  // 4. Request ID Check
  if (requestExpired()) {
    // We still want to cache both the recommendation data and posts, but
    // if the user has switched tabs while we were loading, we don't want
    // multiple requests to compete with each other, rendering out of order.
    Recommended.Logger.log("Aborted rendering due to newer request. Req ID:", requestId);
    measurePerformance();
    return;
  }


  // 5. Render thumbnails
  const renderedPosts = [];
  for (const postId of data.order) {
    const entry = data.results[postId];
    if (!entry) continue;
    const post = posts[postId];
    if (!post || post.flags?.includes("deleted")) continue;
    entry.post = post;

    // Prevent layout shifts by replacing placeholders
    const rendered = Recommended.render(entry);
    if (!rendered) continue;
    $container
      .find(".thumbnail.placeholder").first()
      .replaceWith(rendered);
    renderedPosts.push(rendered);
  }
  Recommended.Logger.log(`Rendered ${renderedPosts.length} posts`, renderedPosts);
  perf.mark("rendered");


  // 6. Apply blacklist
  if (renderedPosts.length > 0) {
    Blacklist.add_posts(renderedPosts);
    Blacklist.update_visibility();
  }


  // 7. Finalize
  Recommended.status = "ready";
  $container.find(".thumbnail.placeholder").remove();
  if ($container.children().length === 0) {
    if (requestExpired()) {
      measurePerformance();
      return; // Unlikely to happen
    }
    Recommended.status = "error";
    $container.html("<p class='info'>Nobody here but us chickens!</p>");
    document.getElementById("post-recommendations")?.remove();
  }

  measurePerformance();
};

// ============================== //
// ======= DOM Management ======= //
// ============================== //

// Uses IntersectionObserver to detect when the recommendations section is in view.
Recommended.waitUntilReady = function () {
  return new Promise((resolve) => {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          observer.disconnect();
          resolve();
        }
      });
    }, { threshold: 0 });

    observer.observe(Recommended.$container[0]);
  });
};

Recommended.render = function (data) {
  // Login-blocked, Safe-blocked, or just missing preview = can't render thumbnail
  if (!data || !data.post || !data.post.preview_url) return null;

  // Flags are returned as an object with boolean values, but we need an array
  let flagArray = [];
  if (data.post.flags.deleted) flagArray.push("deleted");
  if (data.post.flags.pending) flagArray.push("pending");
  if (data.post.flags.flagged) flagArray.push("flagged");

  const article = $("<article>")
    .addClass("thumbnail")
    .attr({
      "data-tags": data.post.tags,

      "data-id": data.post.id,
      "data-flags": data.post.flags,
      "data-rating": data.post.rating,
      "data-file-ext": data.post.file_ext,

      "data-width": data.post.width,
      "data-height": data.post.height,
      "data-size": data.post.size,

      "data-score": data.post.score,
      "data-fav-count": data.post.fav_count,
      "data-is-favorited": data.post.is_favorited,

      "data-uploader": data.post.uploader,
      "data-uploader-id": data.post.uploader_id,

      "data-pools": data.post.pools,

      "data-md5": data.post.md5,
      "data-preview-url": data.post.preview_url,
      "data-sample-url": data.post.sample_url,
      "data-file-url": data.post.file_url,
    });

  // Core
  const link = $("<a>")
    .addClass("thm-link")
    .attr({
      "href": `/posts/${data.post.id}`,
      "data-target": data.post.id,
    })
    .appendTo(article);

  $("<img>")
    .attr({
      "src": data.post.preview_url,
      "alt": "post #" + data.post.id,
    })
    .appendTo(link);

  // Footer
  const footer = $("<div>")
    .addClass(`thm-desc thm-rating-${data.post.rating}`)
    .appendTo(article);

  const descA = $("<span>")
    .addClass("thm-desc-a")
    .appendTo(footer);

  const scoreIcon = data.post.score > 0 ? "arrow_up_dash" : (data.post.score < 0 ? "arrow_down_dash" : "score");

  $("<span>")
    .addClass("thm-desc-m thm-score")
    .addClass(data.post.score > 0 ? "thm-score-positive" : data.post.score < 0 ? "thm-score-negative" : "thm-score-neutral")
    .append(SVGIcon.render(scoreIcon))
    .append(Math.abs(data.post.score))
    .appendTo(descA);

  $("<span>")
    .addClass("thm-desc-m thm-favorites")
    .append(SVGIcon.render("favorites"))
    .append(data.post.fav_count)
    .appendTo(descA);

  $("<span>")
    .addClass("thm-desc-m thm-comments")
    .append(SVGIcon.render("comments"))
    .append(data.post.comment_count)
    .appendTo(descA);

  $("<span>")
    .addClass("thm-desc-b thm-rating")
    .text(data.post.rating.toUpperCase())
    .appendTo(footer);

  return article;
};

Recommended.render_placeholder = function () {
  const article = $("<article>")
    .addClass("thumbnail placeholder");

  return article;
};


// ============================== //
// ======== API Queries ========= //
// ============================== //

// Fetches recommendation data from the server
Recommended.getData = async function (postId, action = "favorites") {
  const target = Recommended.remote_actions.includes(action) ? "remote" : "artist";
  Recommended.Logger.log(`Fetching data: "${postId}/${action}"`);

  return fetch(`/posts/${postId}/similar/${target}.json?mode=${action}&limit=${Recommended.RESULT_COUNT}`)
    .then(
      (response) => {
        if (!response.ok) {
          if (response.status === 502 && target === "remote") {
            Recommended.Logger.log("Recommendation engine is unavailable (502)");
            return {
              post_id: postId,
              model_version: "unavailable",
              results: [],
            };
          }
          console.error(`Failed to fetch recommendations: ${response.statusText}`);
          return;
        }
        return response.json();
      },
      (error) => {
        console.error(`Error fetching recommendations: ${error}`);
      },
    )
    .then((data) => {
      if (!data) return;
      Recommended.Logger.log("Engine response:", data);
      return data;
    });
};

// Fetches post data for the given post IDs
Recommended.getPosts = async function (postIds) {
  Recommended.Logger.log("Fetching posts:", postIds);
  return fetch(`/posts/${Recommended.postId}/similar/lookup.json?post_ids=${postIds.join(",")}`)
    .then(
      (response) => {
        if (!response.ok) {
          console.error(`Failed to fetch posts: ${response.statusText}`);
          return;
        }
        return response.json();
      },
      (error) => {
        console.error(`Error fetching posts: ${error}`);
      },
    )
    .then((data) => {
      if (!data) return;
      Recommended.Logger.log("API response:", data);
      return data;
    });
};


// ============================== //
// ========== Caching =========== //
// ============================== //

Recommended._recommendationCache = {};
Recommended.getCachedRecommendations = function (action) {
  const data = Recommended._recommendationCache[action];
  if (!data) return null;
  return {...data};
};

Recommended.setCachedRecommendations = function (action, data) {
  Recommended._recommendationCache[action] = {...data};
};

Recommended._postCache = {};
Recommended.getCachedPosts = function (postIds) {
  const posts = {};
  for (const postId of postIds) {
    if (Recommended._postCache[postId]) {
      posts[postId] = Recommended._postCache[postId];
    }
  }

  const count = Object.keys(posts).length;
  Recommended.Logger.log(`Posts: ${count}/${postIds.length} cached`);
  if (count === 0) return {};
  return posts;
};

Recommended.setCachedPosts = function (posts) {
  posts.forEach(post => {
    Recommended._postCache[post.id] = post;
  });
};


// ============================== //
// =========== Other ============ //
// ============================== //

$(() => {
  if (!Page.matches("posts", "show")) return;
  Recommended.init();
});

export default Recommended;
