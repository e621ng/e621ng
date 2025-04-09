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
};

FurID.loadMore = function () {
  if (!FurID.manifest[FurID.page]) return;

  for (const one of FurID.manifest[FurID.page]) {
    $("<img />")
      .attr({
        src: FurID.baseURL + one,
        loading: "lazy",
      })
      .appendTo(FurID.wrapper);
  }

  FurID.page++;
};

export default FurID;
