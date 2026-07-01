export default class ProfileCard {

  /**
   * Adjusts the font size of the username to fit within the profile card.
   * This is necessary because users can have very long names that would overflow otherwise.
   */
  public static adjustAvatarNameSize () {
    const element = document.querySelector(".user-card-name a") as HTMLElement;
    console.log("Adjusting avatar name size for element:", element);
    console.log("Element scrollWidth:", element?.scrollWidth, "clientWidth:", element?.clientWidth);
    if (!element || element.scrollWidth <= element.clientWidth) return;

    const fontSize = Math.max(0.5, element.clientWidth / element.scrollWidth);
    console.log("Calculated font size:", fontSize);
    element.style.fontSize = `${fontSize * 1.25}rem`;
  }
}

$(() => {
  ProfileCard.adjustAvatarNameSize();
});
