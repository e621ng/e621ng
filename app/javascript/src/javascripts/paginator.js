const Paginator = {};

Paginator.init_fasttravel = function (button) {
  button.on("click", (event) => {
    event.preventDefault();

    const value = prompt("Navigate to page");
    if (!value) return;

    window.location.replace(button.attr("href").replace("page=0", "page=" + value));
  });
};

$(() => {
  for (const one of $(".paginator a.spacer").get())
    Paginator.init_fasttravel($(one));
});

export default Paginator;
