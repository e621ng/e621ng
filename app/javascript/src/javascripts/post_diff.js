import Page from "./utility/page";

const PostDiff = {};

PostDiff.init = function () {
  const container = document.getElementById("post-diff-container");
  if (!container) return;

  let isDragging = false;

  function setSliderPosition (clientX) {
    const rect = container.getBoundingClientRect();
    let percent = (clientX - rect.left) / rect.width * 100;
    percent = Math.max(0, Math.min(100, percent));
    container.style.setProperty("--split", percent + "%");
  }

  container.addEventListener("mousedown", (e) => {
    isDragging = true;
    setSliderPosition(e.clientX);
    e.preventDefault();
  });

  document.addEventListener("mousemove", (e) => {
    if (!isDragging) return;
    setSliderPosition(e.clientX);
  });

  document.addEventListener("mouseup", () => {
    isDragging = false;
  });

  container.addEventListener("touchstart", (e) => {
    isDragging = true;
    setSliderPosition(e.touches[0].clientX);
    e.preventDefault();
  }, { passive: false });

  document.addEventListener("touchmove", (e) => {
    if (!isDragging) return;
    setSliderPosition(e.touches[0].clientX);
  });

  document.addEventListener("touchend", () => {
    isDragging = false;
  });
};

PostDiff.initSearch = function () {
  const form = $("#post-diff-form");
  $("#post-diff-form-toggle").on("click", (event) => {
    event.preventDefault();
    form.toggleClass("hidden");
  });
};

$(() => {
  if (!Page.matches("moderator-post-diffs", "show")) return;
  PostDiff.init();
  PostDiff.initSearch();
});

export default PostDiff;
