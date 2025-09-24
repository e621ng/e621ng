# frozen_string_literal: true

class ElasticPostVersionQueryBuilder < ElasticQueryBuilder
  def model_class
    PostVersion
  end

  def build
    add_range_relation(:id, :id)

    if q[:updater_name].present?
      user_id = User.name_to_id(q[:updater_name])
      must.push({ term: { updater_id: user_id } }) if user_id
    end

    add_range_relation(:updater_id, :updater_id)
    add_range_relation(:post_id, :post_id)

    if q[:rating].present?
      must.concat(q[:rating].split(",").map { |x| { term: { rating: x.to_s.downcase[0] } } })
    end

    if q[:rating_changed].present?
      if q[:rating_changed] != "any"
        must.push({ term: { rating: q[:rating_changed] } })
      end
      must.push({ term: { rating_changed: true } })
    end

    add_range_relation(:parent_id, :parent_id)

    if q[:parent_id_changed].present?
      if q[:parent_id_changed].is_a?(Integer)
        must.push({ term: { parent_id: q[:parent_id_changed] } })
      else
        must.push({ exists: { field: :parent_id } })
      end
      must.push({ term: { parent_id_changed: true } })
    end

    %i[tags tags_removed tags_added locked_tags locked_tags_removed locked_tags_added].each do |tag_field|
      tags = q[tag_field]
      if tags
        must.concat(TagQuery.scan(tags.downcase).map { |tag| { term: { tag_field => tag } } })
      end
    end

    add_range_relation(:updated_at, :updated_at, type: :date)
    add_text_match(:reason, :reason)
    add_text_match(:description, :description)

    %i[description_changed source_changed].each do |flag|
      add_boolean_match(flag, flag)
    end

    if q[:uploads].present?
      case q[:uploads].downcase
      when "excluded"
        must_not.push({ term: { version: 1 } })
      when "only"
        must.push({ term: { version: 1 } })
      end
    end

    apply_basic_order
  end
end
