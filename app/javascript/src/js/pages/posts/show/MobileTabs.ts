function bootstrapTabs () {
  const container = $(".post-index");
  container.find(".post-mobile-tab").on("click", (event) => {
    const action = $(event.target).data("action");
    container.attr("data-tab-state", action);
  });
}

$(() => {
  bootstrapTabs();
});
