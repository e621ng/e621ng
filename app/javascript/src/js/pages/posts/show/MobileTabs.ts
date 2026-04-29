import LStorage from "@/utility/storage";

function bootstrapTabs () {
  const container = $(".post-display");
  if (!container.length || !container.data("comments-enabled")) return;
  const validActions = ["comments", "tags"];

  const savedState = (LStorage.Posts.MobileTab as any) + "";
  if (savedState === "comments") container.attr("data-tab-state", "comments");

  container.find(".post-mobile-tab").on("click", (event) => {
    const action = $(event.currentTarget).data("action");
    if (!validActions.includes(action)) return;
    LStorage.Posts.MobileTab = action;

    container.attr("data-tab-state", action);
  });
}

function bootstrapGoUpButton () {
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
  bootstrapGoUpButton();
});
