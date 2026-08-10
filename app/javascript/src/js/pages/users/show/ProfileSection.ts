import Local from "@/utility/storage/Local";

/*
Adds the ability to collapse and expand profile sections on the user show page.
The collapsed state of each section is stored in LocalStorage, so it persists across page reloads.
*/
export default class ProfileSection {
  public constructor (wrapper: HTMLElement) {
    const $wrapper = $(wrapper);
    const $header = $wrapper.find(".profile-section-header").first();
    const $body = $wrapper.find(".profile-section-body").first();
    const name = $wrapper.attr("name");
    if (!name || !$header.length || !$body.length) return;

    let state = Local.Users[name];
    if (state) $wrapper.removeClass("hidden").attr("aria-expanded", "true");

    $header.on("click", () => {
      $wrapper.toggleClass("hidden", state)
        .attr("aria-expanded", state ? "false" : "true");

      state = !state;
      Local.Users[name] = state;
    });
  }
}

$(() => {
  for (const one of $((".profile-section")))
    new ProfileSection(one);
});
