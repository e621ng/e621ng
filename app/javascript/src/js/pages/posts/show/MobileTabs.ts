import LStorage from "@/utility/storage";

function bootstrapTabs () {
  const container = $(".post-display");
  const validActions = ["comments", "tags"];

  container.attr("data-tab-state", LStorage.Posts.MobileTab as any);
  container.find(".post-mobile-tab").on("click", (event) => {
    const action = $(event.currentTarget).data("action");
    if (!validActions.includes(action)) return;
    LStorage.Posts.MobileTab = action;

    container.attr("data-tab-state", action);
  });
}

$(() => {
  bootstrapTabs();
});
