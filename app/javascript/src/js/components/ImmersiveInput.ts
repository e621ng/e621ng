export default class ImmersiveInput {

  private input: JQuery<HTMLInputElement>;
  private wrapper: JQuery<HTMLElement>;

  constructor (input: JQuery<HTMLInputElement>) {
    this.input = input;
    this.wrapper = input.parent();
    this.input
      .off("focus.immersive blur.immersive input.immersive")
      .on("focus.immersive", () => {
        this.wrapper.addClass("focused");
        this.updateContentfulState();
      })
      .on("blur.immersive", () => this.wrapper.removeClass("focused"))
      .on("input.immersive", () => this.updateContentfulState());

    // Account for auto-filled inputs on page load
    this.updateContentfulState();
  }

  private updateContentfulState () {
    this.wrapper.toggleClass("contentful", this.input.val()?.length > 0);
  }
}
