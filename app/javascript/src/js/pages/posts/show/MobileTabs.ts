function bootstrapTabs () {
  const container = $(".post-display");
  const validActions = ["comments", "tags"];
  container.find(".post-mobile-tab").on("click", (event) => {
    const action = $(event.currentTarget).data("action");
    if (!validActions.includes(action)) return;
    container.attr("data-tab-state", action);
  });
}

$(() => {
  bootstrapTabs();
});
