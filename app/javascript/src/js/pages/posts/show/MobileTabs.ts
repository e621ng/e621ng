import CStorage from "@/utility/StorageC";

function bootstrapTabs () {
  const container = $(".post-display");
  if (!container.length) return;
  const validActions = ["comments", "tags"];

  container.find(".post-mobile-tab").on("click", (event) => {
    const action = $(event.currentTarget).data("action");
    if (!validActions.includes(action)) return;
    CStorage.postMobileTabState = action;
    switchToTab(container, action);
  });

  // Comment anchor links will not work on mobile unless the user has the comments tab open.
  if (window.innerWidth > 800 || CStorage.postMobileTabState === "comments") return;
  const commentID = window.location.hash.match(/^#?comment-(\d+)/)?.[1];
  if (!commentID) return;
  const comment = $(`article[data-comment-id="${commentID}"]`);
  if (!comment.length) return;

  switchToTab(container, "comments");
  // If the tabs get switched early enough, the browser will scroll to the content on its own.
  window.setTimeout(() => {
    const offset = comment.offset()?.top ?? 0;
    if (offset) window.scrollTo({ top: offset, behavior: "smooth" });
  }, 100);
}

function switchToTab (container: JQuery<HTMLElement>, tab: "comments" | "tags") {
  container
    .attr("data-tab-state", tab)
    .find(".post-mobile-tab").each((_, el) => {
      const $el = $(el);
      $el.attr("aria-selected", String($el.data("action") === tab));
    });
}

function bootstrapGoUpButton () {
  $(".go-up button").on("click", () => {
    window.scrollTo({ top: 0, behavior: "smooth" });
  });
}

$(() => {
  bootstrapTabs();
  bootstrapGoUpButton();
});
