import Page from "./utility/page";
import SVGIcon from "./utility/svg_icon";
import LStorage from "./utility/storage";

const Recommended = {};

Recommended.RESULT_COUNT = 6;
Recommended.SHOW_ENGINE_RESULTS = false;
Recommended.debug = LStorage.get("e6.debug", false);
Recommended.allStates = ["artist", "favorites", "tags", "closed"];
Recommended.validStates = ["artist", "closed"];

Recommended.remote_actions = ["favorites", "tags"];

Recommended.init = function () {
  if (Recommended.$container.length === 0) return;
  if (Recommended.action === "closed") {
    Recommended.$wrapper.remove();
    return;
  }

  Recommended.SHOW_ENGINE_RESULTS = Recommended.$wrapper.attr("data-remote") === "true";
  if (Recommended.SHOW_ENGINE_RESULTS)
    Recommended.validStates.push("favorites", "tags");
  Recommended.debugLog("Loaded", {
    action: Recommended.action,
    showEngineResults: Recommended.SHOW_ENGINE_RESULTS,
    validStates: Recommended.validStates,
  });

  Recommended.$wrapper.attr("data-action", Recommended.action);

  // Detect when the recommendations section is in view.
  let isInitialized = false;
  Recommended.waitUntilReady().then(() => {
    isInitialized = true;
    Recommended.loadState();
  });

  // Rig tabs
  $("#post-recommendations-tabs").on("click", "button", (event) => {
    if (!isInitialized) return;

    if (Recommended.status === "loading")
      return;

    const action = $(event.currentTarget).data("action");
    Recommended.action = action;
    if (action == "closed") {
      Recommended.$wrapper.remove();
      return;
    }

    Recommended.$wrapper.attr("data-action", action);
    Recommended.loadState(action);
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


// ============================== //
// ====== State Management ====== //
// ============================== //

Recommended.loadState = async function (action = Recommended.action) {
  Recommended.debugLog(`Loading state: "${action}"`);
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
      Recommended.status = "error";
      $container.html("<p class='error'>Failed to load recommendations.</p>");
      return;
    }
    Recommended.setCachedRecommendations(action, data);
  } else Recommended.debugLog("Using cached recommendations:", data);

  const resultsById = {};
  for (const result of data.results)
    resultsById[result.post_id] = result;
  data.results = resultsById;

  // 3. Fetch post data for recommended posts
  const recommendedPostIds = Object.keys(data.results);
  let posts = Recommended.getCachedPosts(recommendedPostIds);
  let missingPostIds = recommendedPostIds.filter(id => !posts[id]);
  if (missingPostIds.length > 0) {
    const postLookup = await Recommended.getPosts(missingPostIds);
    if (postLookup) {
      for (const post of postLookup) posts[post.id] = post;
      Recommended.setCachedPosts(postLookup);
    } else {
      Recommended.status = "error";
      $container.html("<p class='error'>Failed to load recommended posts.</p>");
      return;
    }
  }

  // 4. Render thumbnails
  for (const postId of recommendedPostIds) {
    const entry = data.results[postId];
    if (!entry) continue;
    const post = posts[postId];
    if (post.flags.deleted) continue;
    entry.post = post;

    // Prevent layout shifts by replacing placeholders
    $container
      .find(".thumbnail.placeholder").first()
      .replaceWith(Recommended.render(entry));
  }

  // 5. Finalize
  Recommended.status = "ready";
  $container.find(".thumbnail.placeholder").remove();
  if ($container.children().length === 0) {
    Recommended.status = "error";
    $container.html("<p class='info'>No recommendations found.</p>");
  }
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
    }, { threshold: 0.1 });

    observer.observe(Recommended.$container[0]);
  });
};

Recommended.render = function (data) {
  const article = $("<article>")
    .addClass("thumbnail")
    .data({
      id: data.post.id,
    });

  // Core
  const link = $("<a>")
    .addClass("thm-link")
    .attr("href", `/posts/${data.post.id}`)
    .appendTo(article);

  $("<img>")
    .attr({
      "src": data.post.preview.url,
      "alt": "post #" + data.post.id,
    })
    .appendTo(link);

  // Footer
  const footer = $("<div>")
    .addClass("thm-desc")
    .addClass(`thm-rating-${data.post.rating}`)
    .appendTo(article);

  const descA = $("<span>")
    .addClass("thm-desc-a")
    .appendTo(footer);

  $("<span>")
    .addClass("thm-desc-m")
    .addClass("thm-score")
    .addClass(data.post.score.total > 0 ? "thm-score-positive" : data.post.score.total < 0 ? "thm-score-negative" : "thm-score-neutral")
    .append(SVGIcon.render("score"))
    .append(data.post.score.total)
    .appendTo(descA);

  $("<span>")
    .addClass("thm-desc-m")
    .addClass("thm-favorites")
    .append(SVGIcon.render("favorites"))
    .append(data.post.fav_count)
    .appendTo(descA);

  $("<span>")
    .addClass("thm-desc-m")
    .addClass("thm-comments")
    .append(SVGIcon.render("comments"))
    .append(data.post.comment_count)
    .appendTo(descA);

  $("<span>")
    .addClass("thm-desc-b")
    .addClass("thm-rating")
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
  const url = Recommended.remote_actions.includes(action)
    ? `/posts/recommended.json?post_id=${postId}&mode=${action}&limit=${Recommended.RESULT_COUNT}`
    : `/posts/${postId}/recommended.json?limit=${Recommended.RESULT_COUNT}`;
  Recommended.debugLog(`Fetching data: "${postId}/${action}"`);

  return fetch(url)
    .then(
      (response) => {
        if (!response.ok) {
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
      Recommended.debugLog("Engine response:", data);
      return data;
    });
};

// Fetches post data for the given post IDs
Recommended.getPosts = async function (postIds) {
  Recommended.debugLog("Fetching posts:", postIds);
  return fetch(`/posts.json?tags=id:${postIds.join(",")}`)
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
      Recommended.debugLog("API response:", data);
      return data.posts;
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
  Recommended.debugLog(`Posts: ${count}/${postIds.length} cached`);
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

Recommended.debugLog = function (...args) {
  if (!Recommended.debug) return;
  console.log("\x1B[36m[Recommended]\x1B[0m", ...args);
};

$(() => {
  if (!Page.matches("posts", "show")) return;
  Recommended.init();
});

export default Recommended;
