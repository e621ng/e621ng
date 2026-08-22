import OtpCodeInput from "@/components/OtpCodeInput";
import Page from "@/utility/Page";

$(() => {
  if (!Page.matches("sessions", "totp")) return;

  for (const el of $("[data-otp-code-input]"))
    new OtpCodeInput($(el as HTMLElement));
});
