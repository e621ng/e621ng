import E621Type from "@/interfaces/E621";

declare const E621: E621Type;

$(() => {
  const tag_list_cache = {};
  for (const entry of $("li.tag-list-item"))
    tag_list_cache[decodeURIComponent(entry.dataset.name)] = $(entry);

  for (const one of E621.CurrentUser.blacklist) {
    if (one.includes(" ") || !tag_list_cache[one]) continue;
    tag_list_cache[one].addClass("blacklisted");
  }

  $(".tag-list-actions button").on("click", (event) => {
    const target = $(event.currentTarget);
    const tag = target.data("tag");
    if (!tag) return;

    if (E621.CurrentUser.blacklist.includes(tag)) {
      if (!confirm(`Are you sure you want to remove "${tag}" from your blacklist?`)) return;
      E621.CurrentUser.blacklist = E621.CurrentUser.blacklist.filter(n => n !== tag);
      target.parents(".tag-list-item").removeClass("blacklisted");
    } else {
      if (!confirm(`Are you sure you want to add "${tag}" to your blacklist?`)) return;
      E621.CurrentUser.blacklist.push(tag);
      target.parents(".tag-list-item").addClass("blacklisted");
    }
  });

  // Regenerate sidebar toggles
  document.addEventListener("e621:blacklistUpdated", () => {
    $("li.tag-list-item.blacklisted").removeClass("blacklisted");
    for (const one of E621.CurrentUser.blacklist) {
      if (one.includes(" ") || !tag_list_cache[one]) continue;
      tag_list_cache[one].addClass("blacklisted");
    }
  });
});
