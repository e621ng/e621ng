import Page from "./utility/page";
import SVGIcon from "./utility/svg_icon";

const Recommended = {};

Recommended.init = function () {
  const $container = $("#post-recommendations-list");
  if ($container.length === 0) return;

  const postId = $container.data("post-id");
  Recommended.getData(postId).then(async (data) => {
    if (!data || !data.results) return;
    const resultsById = data.results.reduce((acc, result) => {
      acc[result.post_id] = result;
      return acc;
    }, {});

    const recommendedPostIds = Object.keys(resultsById);
    const posts = await Recommended.getPosts(recommendedPostIds);
    if (!posts) return;

    for (const post of posts) {
      // TODO check if post is deleted

      const entry = resultsById[post.id];
      if (!entry) continue;
      entry.post = post;
      Recommended.render(entry).appendTo($container);
    }
  });
};

Recommended.getData = async function (postId) {
  return fetch(`/posts/recommended.json?post_id=${postId}&explain=true`)
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

$(() => {
  if (!Page.matches("posts", "show")) return;
  Recommended.init();
});

export default Recommended;
