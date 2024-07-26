import Cookie from "./cookie";

const GuestWarning = {
  init () {
    const hider = $(".guest-warning");
    const gw = Cookie.get("gw");
    if (gw === "seen" || $("#a-terms-of-service").length > 0) {
      return;
    }
    hider.show();
    $("#guest-warning-accept").on("click", function () {
      Cookie.put("gw", "seen");
      hider.hide();
    });
    $("#guest-warning-decline").on("click", function () {
      Cookie.put("gw", "reject");
      window.location.assign("https://www.google.com/");
    });
  },
};

$(document).ready(function () {
  GuestWarning.init();
});

export default GuestWarning;
