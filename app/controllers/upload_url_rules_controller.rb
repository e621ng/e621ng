# frozen_string_literal: true

class UploadUrlRulesController < ApplicationController
  respond_to :html, :json
  before_action :logged_in_only, only: %i[index check]
  before_action :staff_only, only: %i[new create edit update destroy]
  before_action :load_rule, only: %i[edit update destroy]
  before_action :check_throttle, only: %i[check]

  def index
    @rules = UploadUrlRule.search(search_params).paginate(params[:page], limit: params[:limit])
    respond_with(@rules)
  end

  def new
    @rule = UploadUrlRule.new(handling: "recommend")
  end

  def edit
  end

  def create
    @rule = UploadUrlRule.new(rule_params)
    return run_test(:new) if testing?

    if @rule.save
      redirect_to(upload_url_rules_path, notice: "Rule created")
    else
      render(:new)
    end
  end

  def update
    @rule.assign_attributes(rule_params)
    return run_test(:edit) if testing?

    if @rule.save
      redirect_to(upload_url_rules_path, notice: "Rule updated")
    else
      render(:edit)
    end
  end

  def destroy
    @rule.destroy
    redirect_to(upload_url_rules_path, notice: "Rule deleted")
  end

  def check
    result = UploadUrlRule.evaluate(params[:url].is_a?(String) ? params[:url] : "")
    if result.nil?
      render json: { match: false }
    else
      render json: { match: true }.merge(result.to_h)
    end
  rescue UploadUrlRule::UncheckableUrlError
    render json: { error: "url_uncheckable" }, status: 422
  rescue UploadUrlRule::EvaluationError => e
    render json: { error: "rule_failed", label: e.label }, status: 422
  end

  private

  def testing?
    params[:commit] == "Test"
  end

  # Applies the unsaved rule to the test URL and re-renders the form. Nothing is saved.
  def run_test(template)
    @test_url = params[:test_url].to_s
    if @rule.valid?
      @test_canonical = UploadUrlRule.canonicalize(@test_url)
      begin
        @test_result = @rule.apply(@test_url)
      rescue UploadUrlRule::EvaluationError
        @test_error = "The pattern timed out on this URL. Uploads matching it would be refused."
      end
    end
    @tested = true
    render(template)
  end

  def check_throttle
    return if Danbooru.config.disable_throttles?
    raise APIThrottled if RateLimiter.throttle!("upload_url_check:#{CurrentUser.id}", limit: 60, period: 1.minute)
  end

  def load_rule
    @rule = UploadUrlRule.find(params.expect(:id))
  end

  def search_params
    permit_search_params %i[label pattern handling enabled order]
  end

  def rule_params
    params.expect(upload_url_rule: %i[label pattern replacement handling message enabled])
  end
end
