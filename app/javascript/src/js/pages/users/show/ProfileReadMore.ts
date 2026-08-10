/*
Adds "Show More" buttons to profile sections that are too long to fit in their container.
When clicked, the button expands the section to show all of its content.
*/
export default class ProfileReadMore {
  public static init_readmore (wrapper: HTMLElement) {
    const $wrapper = $(wrapper);
    const button = $wrapper.find(".content-readmore");

    let expanded = false;
    const updateShowMore = () => {
      if (expanded) $wrapper.removeClass("expanded");

      if (wrapper.scrollHeight > wrapper.clientHeight) {
        $wrapper.addClass("expandable");
        if (expanded) $wrapper.addClass("expanded");
      } else {
        $wrapper.removeClass("expandable expanded");
        expanded = false;
        button.text("Show More");
      }
    };

    button.on("click", () => {
      expanded = !expanded;
      $wrapper.toggleClass("expanded", expanded);
      button.text(`Show ${expanded ? "Less" : "More"}`);
    });

    // Update the button visibility when DText sections are opened and closed.
    wrapper.addEventListener("toggle", (event) => {
      if (!(event.target instanceof HTMLDetailsElement)) return;
      updateShowMore();
    }, true);

    // Update the button visibility when the window is resized.
    let timer: number | null = null;
    const observer = new ResizeObserver(() => {
      if (timer !== null) clearTimeout(timer);
      timer = window.setTimeout(updateShowMore, 100);
    });
    observer.observe(wrapper);

    updateShowMore();
  }
}

$(() => {
  for (const one of $(".profile-readmore .content"))
    ProfileReadMore.init_readmore(one);
});
