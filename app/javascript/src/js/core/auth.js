const Auth = {};

Auth.init = function () {
  let loginFormShown = false;
  $(".auth-login-link").on("click", async (event) => {
    event.preventDefault();
    const form = await Auth.renderLoginForm();
    loginFormShown = !loginFormShown;
    form.toggleClass("hidden", !loginFormShown);
  });
};

Auth._loginForm = null;
Auth.renderLoginForm = async function () {
  if (Auth._loginForm) return Auth._loginForm;

  return new Promise((resolve, reject) => {
    $.ajax({
      url: "/auth/login",
      dataType: "html",
      timeout: 10000,
      success: (html) => {
        Auth._loginForm = $("<div>")
          .attr({ "id": "auth-overlay" })
          .addClass("hidden")
          .html(html)
          .appendTo("body");

        Auth._loginForm.find(".st-immersive-input > input")
          .each((_, input) => new ImmersiveInput($(input)));

        resolve(Auth._loginForm);
      },
      error: () => {
        console.error("Avatar menu: failed to load content");
        reject();
      },
    });
  });
};

$(() => { Auth.init(); });
export default Auth;

class ImmersiveInput {

  constructor (input) {
    this.input = input;
    this.wrapper = input.parent();
    this.input.on("focus", () => this.wrapper.addClass("focused"));
    this.input.on("blur", () => this.wrapper.removeClass("focused"));

    this.input.on("input", (event) => {
      this.wrapper.toggleClass("contentful", event.target.value.length > 0);
    });
  }
}
