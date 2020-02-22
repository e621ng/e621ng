class ForumCategoriesController < ApplicationController
  respond_to :html
  before_action :admin_only

  def index
    @forum_cats = ForumCategory.paginate(params[:page], limit: 50, order: "forum_categories.order ASC, forum_categories.id ASC")
    @new_cat = ForumCategory.new
    @user_levels = [['Anyone', 0]] + User.level_hash.to_a
  end

  def create
    @cat = ForumCategory.create(category_params)
    if @cat.valid?
      ModAction.log(:forum_category_create, {forum_category_id: @cat.id})
      flash[:notice] = "Category created"
    else
      flash[:notice] = @cat.errors.full_messages.join('; ')
    end
    redirect_to forum_categories_path
  end

  def destroy
    @cat = ForumCategory.find(params[:id])
    @cat.destroy
    ModAction.log(:forum_category_delete, {forum_category_id: @cat.id})
    respond_with(@cat)
  end

  def update
    @cat = ForumCategory.find(params[:id])
    @cat.update(category_params)

    if @cat.valid?
      ModAction.log(:forum_category_update, {forum_category_id: @cat.id})
      flash[:notice] = "Category updated"
    else
      flash[:notice] = @cat.errors.full_messages.join('; ')
    end
    redirect_to forum_categories_path
  end

  private

  def category_params
    params.require(:forum_category).permit([:name, :description, :can_create, :can_reply, :can_view, :order])
  end
end
