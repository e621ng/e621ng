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

  $(".go-up button").on("click", () => {
    const tabs = $("#mobile-tabs");
    if (tabs.length) {
      let offset = tabs.offset()?.top ?? 0;
      if (offset) offset -= window.innerHeight / 2;
      window.scrollTo({ top: offset, behavior: "smooth" });
    } else
      window.scrollTo({ top: 0, behavior: "smooth" });
  });
}

$(() => {
  bootstrapTabs();
});
