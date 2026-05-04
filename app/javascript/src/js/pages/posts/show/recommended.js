import Page from "@/utility/Page";
import LStorage from "@/utility/storage";
import Blacklist from "@/core/blacklists";
import Analytics from "@/core/analytics";
import Logger from "@/utility/Logger";
import PerformanceTracker from "@/utility/PerformanceTracker";
import Settings from "@/utility/Settings";
import CStorage from "@/utility/StorageC";
import PostCache from "@/models/PostCache";
import ThumbnailEngine from "@/components/ThumbnailEngine";

const Recommended = {};

Recommended.RESULT_COUNT = 6;
Recommended.SHOW_ENGINE_RESULTS = false;
Recommended.Logger = new Logger("Recommended");
Recommended.allStates = ["artist", "tags", "favorites"];
Recommended.validStates = ["artist", "tags"];
Recommended.requestID = 0;

Recommended.remote_actions = ["favorites"];

Recommended.init = function () {
  if (Recommended.$container.length === 0) return;

  Recommended.SHOW_ENGINE_RESULTS = Settings.Recommender.remote;
  if (Recommended.SHOW_ENGINE_RESULTS)
    Recommended.validStates = [...Recommended.validStates, ...Recommended.remote_actions];

  let initialAction = Recommended.action;
  // Determine which states are actually available based on the presence of tabs in the DOM.
  Recommended.validStates = Recommended.validStates.filter((state) => {
    return $(`#post-recommendations-tab-${state}`).length > 0;
  });
  if (Recommended.validStates.length === 0) {
    Recommended.Logger.log("No valid recommendation states available.");
    Recommended.$wrapper.hide();
    return;
  }

  if (!Recommended.validStates.includes(initialAction))
    initialAction = Recommended.validStates[0];

  Recommended.Logger.log(
    "Loaded",
    `\n ⤷ Initial Action: ${initialAction}`,
    `\n ⤷ Valid Actions: ${Recommended.validStates.join(", ")}`,
    `\n ⤷ Remote Engine Enabled: ${Recommended.SHOW_ENGINE_RESULTS}`,
  );


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

  // ===== UTILITY ===== //

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

  // ===== BEGIN ===== //

  Recommended.Logger.log(`Loading state: "${action}" (Req ID: ${requestId})`);
  const $container = Recommended.$container;

  if (!Recommended.validStates.includes(action)) {
    if (Recommended.validStates.length === 0) {
      Recommended.Logger.log("No valid recommendation states available.");
      Recommended.status = "error";
      $container.html("<p class='error'>No recommendations available.</p>");
      return;
    }
    action = Recommended.validStates[0];
    Recommended.action = action;
  }


  // 1. Render skeleton placeholders
  if (Recommended.status !== "waiting") {
    Recommended.status = "waiting";

    // Prune old thumbnails from PostCache before clearing the container
    $container.find(".thumbnail").each((_, element) => {
      PostCache.prune($(element));
    });
    Recommended.Logger.log("Thumbnails pruned", PostCache.stats());
    $container.empty();

    for (let i = 0; i < Recommended.RESULT_COUNT; i++)
      $container.append(ThumbnailEngine.renderPlaceholder());
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
      Recommended.Logger.log("Cache state:", PostCache.stats());
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
      Recommended.setCachedPosts(postLookup);
      posts = Recommended.getCachedPosts(data.order); // Get the updated cache state
      Recommended.Logger.log("Cache state:", PostCache.stats());
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
    const rendered = ThumbnailEngine.render(post);
    if (!rendered) continue;
    $container
      .find(".thumbnail.placeholder").first()
      .replaceWith(rendered);
    renderedPosts.push(rendered);
  }


  // 6. Apply blacklist
  if (renderedPosts.length > 0) {
    Blacklist.add_posts(renderedPosts); // Automatically registers thumbnails with PostCache too
    Blacklist.update_visibility();
  }
  Recommended.Logger.log(`Rendered ${renderedPosts.length} posts`, renderedPosts);
  Recommended.Logger.log(" ⤷ Cache state:", PostCache.stats());
  perf.mark("rendered");


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


// ============================== //
// ======== API Queries ========= //
// ============================== //

// Fetches recommendation data from the server
Recommended.getData = async function (postId, action = "favorites") {
  let target;
  if (Recommended.remote_actions.includes(action)) target = "remote";
  else if (Recommended.validStates.includes(action)) target = action;
  else throw new Error(`Invalid recommendation action: ${action}`);
  Recommended.Logger.log(`Fetching data: "${postId}/${action}"`);

  return fetch(`/posts/${postId}/similar/${target}.json?limit=${Recommended.RESULT_COUNT}`)
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
  return fetch(`/posts.json?v2=true&mode=thumbnail&tags=id:${postIds.join(",")}`)
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

Recommended.getCachedPosts = function (postIds) {
  const posts = PostCache.getManyByID(postIds);
  const count = Object.keys(posts).length;
  Recommended.Logger.log(`Posts: ${count}/${postIds.length} cached`);
  if (count === 0) return {};
  return posts;
};

Recommended.setCachedPosts = function (posts) {
  posts.forEach(post => {
    PostCache.fromDeferredPosts(post.id, post);
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
