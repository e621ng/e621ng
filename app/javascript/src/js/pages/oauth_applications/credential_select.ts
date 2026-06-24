// Click anywhere in a credential input (client_id, secret) to select the
// whole value. Saves users a triple-click when copying.
document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll<HTMLInputElement>(".oauth-app-readonly input[readonly]").forEach((input) => {
    input.addEventListener("focus", () => input.select());
    input.addEventListener("click", () => input.select());
  });
});
