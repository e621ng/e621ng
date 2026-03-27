import Page from "./utility/page";
import SVGIcon from "./utility/svg_icon";
import LStorage from "./utility/storage";

const Recommended = {};

Recommended.RESULT_COUNT = 6;

Recommended.init = function () {
  if (Recommended.$container.length === 0) return;
  if (Recommended.action === "closed") {
    Recommended.$wrapper.remove();
    return;
  }
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
    return LStorage.Posts.Recommendations;
  },
  set: function (value) {
    if (["favorites", "tags", "closed"].includes(value)) {
      LStorage.Posts.Recommendations = value;
      this.$wrapper.attr("data-action", value);
    }
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
  const $container = Recommended.$container;

  // Loading steps:
  if (Recommended.status !== "waiting") {
    Recommended.status = "waiting";
    $container.empty();
    for (let i = 0; i < Recommended.RESULT_COUNT; i++)
      $container.append(Recommended.render_placeholder());
  }

  // 2. Fetch recommendations data
  Recommended.status = "loading";
  const data = await Recommended.getData(Recommended.postId, action);
  if (!data || !data.results) {
    Recommended.status = "error";
    $container.html("<p class='error'>Failed to load recommendations.</p>");
    return;
  }

  const resultsById = data.results.reduce((acc, result) => {
    acc[result.post_id] = result;
    return acc;
  }, {});

  // 3. Fetch post data for recommended posts
  const recommendedPostIds = Object.keys(resultsById);
  const posts = await Recommended.getPosts(recommendedPostIds);
  if (!posts) {
    Recommended.status = "error";
    $container.html("<p class='error'>Failed to load recommended posts.</p>");
    return;
  }

  // 4. Render thumbnails
  for (const post of posts) {
    if (post.flags.deleted) continue;

    const entry = resultsById[post.id];
    if (!entry) continue;
    entry.post = post;

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
    .attr("src", data.post.preview.url)
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
    .addClass(data.post.score > 0 ? "thm-score-positive" : data.post.score < 0 ? "thm-score-negative" : "thm-score-neutral")
    .append(SVGIcon.render("score"))
    .appendTo(descA);

  $("<span>")
    .addClass("thm-desc-m")
    .addClass("thm-favorites")
    .append(SVGIcon.render("favorites"))
    .appendTo(descA);

  $("<span>")
    .addClass("thm-desc-m")
    .addClass("thm-comments")
    .append(SVGIcon.render("comments"))
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
  return fetch(`/posts/recommended.json?post_id=${postId}&mode=${action}&limit=${Recommended.RESULT_COUNT}`)
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
      console.log("fetched recommendations");
      console.log(data);
      return data;
    });
};

// Fetches post data for the given post IDs
Recommended.getPosts = async function (postIds) {
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
      console.log("fetched posts");
      console.log(data);
      return data.posts;
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
