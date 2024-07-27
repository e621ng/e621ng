$(function () {
  $("#maintoggle").on("click.danbooru", function (e) {
    e.preventDefault();
    $("#nav").toggle();
    $("#maintoggle-on").toggle();
    $("#maintoggle-off").toggle();
  });
});
