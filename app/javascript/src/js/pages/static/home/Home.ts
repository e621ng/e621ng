import State from "@/utility/StateUtils";

class Home {
  // Search buttons
  static bootstrapSearch (): void {
    const form = document.getElementById("home-search-form") as HTMLFormElement;
    const tags = document.getElementById("tags") as HTMLInputElement;
    if (!form || !tags) return;

    let isEmpty = !tags.value;
    let wasEmpty = isEmpty;
    // Start in default state, switch to non-empty if tags are pre-filled (ex. from navigating back to the page)
    if (!isEmpty) form.classList.remove("empty");

    tags.addEventListener("input", () => {
      wasEmpty = isEmpty;
      isEmpty = !tags.value;

      if (isEmpty && !wasEmpty) form.classList.add("empty");
      else if (!isEmpty && wasEmpty) form.classList.remove("empty");
    });

    for (const link of document.querySelectorAll<HTMLAnchorElement>(".home-buttons a")) {
      link.addEventListener("click", (event) => {
        if (isEmpty) return; // Act like regular links

        event.preventDefault();
        const extraTags = link.getAttribute("data-tags");
        if (extraTags && !tags.value.includes(extraTags))
          tags.value = tags.value + (tags.value.endsWith(" ") ? "" : " ") + extraTags;

        form.requestSubmit();
      });
    }
  }

  // Trends toggle
  static bootstrapTrends (): void {
    const trends = document.getElementById("home-trends");
    if (!trends) return;
    const trendsToggle = trends.querySelector("h3");
    if (!trendsToggle) return;

    if (this.trends) {
      trends.classList.remove("hidden");
      trendsToggle.setAttribute("aria-expanded", "true");
    }
    window.setTimeout(() => trends.classList.add("animated"), 500); // Don't animate on page load

    trendsToggle.addEventListener("click", () => {
      this.trends = !this.trends;
      trends.classList.toggle("hidden", !this.trends);
      trendsToggle.setAttribute("aria-expanded", this.trends ? "true" : "false");
    });
  }

  static _trends: boolean;
  static get trends (): boolean {
    if (typeof this._trends !== "boolean")
      this._trends = localStorage.getItem("e6.rising.shown") !== "false";
    return this._trends;
  }

  static set trends (value: boolean) {
    this._trends = value;
    localStorage.setItem("e6.rising.shown", value.toString());
  }

}

State.onReady(() => {
  Home.bootstrapSearch();
  Home.bootstrapTrends();
});
