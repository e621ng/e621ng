# frozen_string_literal: true

# Shared gate for the public account-recovery forms (password reset, login
# reminder). Both mail the same address, so they share one budget.
module RecoveryRequestGuard
  extend ActiveSupport::Concern

  GENERIC_NOTICE = "If your email was on file, an email has been sent your way. It should arrive within the next few minutes. Make sure to check your spam folder."

  private

  # Order matters: the IP limiter counts captcha failures too, so a bot cannot make
  # us hammer siteverify; the per-email limiter runs after the captcha so a bot
  # cannot exhaust the real owner's budget. The email cap drops silently so the
  # response never reveals whether an address is on file.
  #
  # :rejected => already redirected; :dropped => show the generic notice but skip
  # the lookup; :allowed => proceed.
  def throttle_recovery_request(email, redirect_path, log_key)
    if RateLimiter.throttle!("account_recovery:#{request.remote_ip}", limit: 5, period: 1.hour)
      DanbooruLogger.add_attributes(log_key => "rate_limited")
      redirect_to redirect_path, notice: "Too many requests. Try again later."
      return :rejected
    end

    if Danbooru.config.enable_turnstile? && !TurnstileVerifier.verify(params["cf-turnstile-response"], request.remote_ip)
      DanbooruLogger.add_attributes(log_key => "captcha_failed")
      redirect_to redirect_path, notice: "Captcha verification failed, please try again"
      return :rejected
    end

    normalized = email.to_s.strip.downcase
    if normalized.present? && normalized.length <= 100 &&
       RateLimiter.throttle!("account_recovery:email:#{normalized}", limit: 3, period: 1.hour)
      DanbooruLogger.add_attributes(log_key => "email_rate_limited")
      return :dropped
    end

    :allowed
  end
end
