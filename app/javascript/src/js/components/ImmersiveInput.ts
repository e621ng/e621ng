export default class ImmersiveInput {

  private input: JQuery<HTMLInputElement>;
  private wrapper: JQuery<HTMLElement>;

  constructor (input: JQuery<HTMLInputElement>) {
    this.input = input;
    this.wrapper = input.parent();
    this.input
      .off("focus.immersive blur.immersive input.immersive")
      .on("focus.immersive", () => this.wrapper.addClass("focused"))
      .on("blur.immersive", () => this.wrapper.removeClass("focused"))
      .on("input.immersive", (event) => {
        this.wrapper.toggleClass("contentful", event.target.value.length > 0);
      });
  }
}
