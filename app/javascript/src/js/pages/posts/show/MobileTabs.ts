import CStorage from "@/utility/StorageC";

function bootstrapTabs () {
  const container = $(".post-display");
  if (!container.length) return;
  const validActions = ["comments", "tags"];

  container.find(".post-mobile-tab").on("click", (event) => {
    const action = $(event.currentTarget).data("action");
    if (!validActions.includes(action)) return;
    CStorage.postMobileTabState = action;

    container
      .attr("data-tab-state", action)
      .find(".post-mobile-tab").each((_, el) => {
        const $el = $(el);
        $el.attr("aria-selected", String($el.data("action") === action));
      });
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
