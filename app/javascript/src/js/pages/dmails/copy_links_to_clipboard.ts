class DMails {
  static init () {
    const shareLink = document.querySelector<HTMLAnchorElement>(`a[href^=${document.location.pathname.replace(/\//g, "\\/")}\\?key]`);
    if (!shareLink) return;
    const url = shareLink.href;
    shareLink.onclick = (e) => {
      e.preventDefault();
      e.stopImmediatePropagation();
      try {
        navigator.clipboard.writeText(url).then(() => {
          // TODO: Copied notification
          console.log("Copied Successfully!");
          alert("Copied Successfully!");
        });
      } catch (error) {
        console.warn("Failed! %o", error);
        alert(`Failed to automatically copy sharable link.\n\nLink: ${url}`);
        // window.location.href = url;
      }
    };
  }
};

$(() => DMails.init());

export default DMails;
