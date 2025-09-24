const FurID = {};

FurID.baseURL = "";
FurID.wrapper = null;
FurID.manifest = [];
FurID.page = 0;

FurID.initialize = async function () {
  FurID.baseURL = window.furidURL;
  FurID.wrapper = $("#a-furid");

  // Manifest file lists all furID files, ordered by score.
  // See the "misc" repo to generate one automatically.
  const manifestRequest = await fetch(FurID.baseURL + "manifest.json");
  const fullManifest = await manifestRequest.json();
  FurID.manifest = [];
  FurID.page = 0;

  // Slice the manifest into content pages
  // Loading everything at once causes a lag spike
  for (let i = 0; i < fullManifest.length; i += 100) {
    FurID.manifest.push(fullManifest.slice(i, i + 100));
  }

  // Load more content pages as the user scrolls down
  const io = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;

      // Somehow, the check below failed,
      // so the entry page does not exist
      if (!FurID.manifest[FurID.page]) {
        io.disconnect();
        return;
      }

      // Stop observing if running out of
      // content pages to display
      if (FurID.manifest[FurID.page].length != 100) {
        io.disconnect();
      }

      FurID.loadMore();
    });
  });

  io.observe(document.getElementById("furid_end_of_content"));

  // Load more content to fill up the entire screen if necessary
  if (FurID.manifest[FurID.page] != undefined && FurID.wrapper.innerHeight() < window.innerHeight) {
    FurID.loadMore();
  }
};

FurID.loadMore = function () {
  if (!FurID.manifest[FurID.page]) return;

  for (const one of FurID.manifest[FurID.page]) {
    const image = $("<img />")
      .attr({
        src: FurID.baseURL + one,
        loading: "lazy",
      })
      .appendTo(FurID.wrapper)
      .one("error", () => {
        image.remove();
      });
  }

  FurID.page++;
};

export default FurID;
