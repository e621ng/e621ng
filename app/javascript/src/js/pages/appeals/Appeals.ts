document.addEventListener("DOMContentLoaded", () => {
  const status = document.getElementById("appeal_status") as HTMLSelectElement | null;
  const submit = document.getElementById("appeal-display-submit-button") as HTMLButtonElement | null;
  if (status && submit) {
    status.addEventListener("change", () => submit.disabled = (status.value === ""));
  }
});
