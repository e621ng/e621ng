$(() => {
  const container = $("#image-container")
    .off("click.blacklist")
    .on("click.blacklist", () => {
      if (!container.hasClass("blacklisted")) return;
      container.removeClass("blacklisted");

      $("#note-container").css("visibility", "visible");
    });
});
