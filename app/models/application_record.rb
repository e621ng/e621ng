class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  concerning :SearchMethods do
    class_methods do
      def paginate(page, options = {})
        extending(Danbooru::Paginator::ActiveRecordExtension).paginate(page, options)
      end

      def qualified_column_for(attr)
        "#{table_name}.#{column_for_attribute(attr).name}"
      end

      def where_like(attr, value)
        where("#{qualified_column_for(attr)} LIKE ? ESCAPE E'\\\\'", value.to_escaped_for_sql_like)
      end

      def where_ilike(attr, value)
        where("lower(#{qualified_column_for(attr)}) LIKE ? ESCAPE E'\\\\'", value.downcase.to_escaped_for_sql_like)
      end

      def attribute_exact_matches(attribute, value, **options)
        return all unless value.present?

        column = qualified_column_for(attribute)
        where("#{column} = ?", value)
      end

      def attribute_matches(attribute, value, **options)
        return all if value.nil?

        column = column_for_attribute(attribute)
        case column.sql_type_metadata.type
        when :boolean
          boolean_attribute_matches(attribute, value, **options)
        when :integer, :datetime
          numeric_attribute_matches(attribute, value, **options)
        when :string, :text
          text_attribute_matches(attribute, value, **options)
        else
          raise ArgumentError, "unhandled attribute type"
        end
      end

      def boolean_attribute_matches(attribute, value)
        if value.to_s.truthy?
          value = true
        elsif value.to_s.falsy?
          value = false
        else
          raise ArgumentError, "value must be truthy or falsy"
        end

        where(attribute => value)
      end

      # range: "5", ">5", "<5", ">=5", "<=5", "5..10", "5,6,7"
      def numeric_attribute_matches(attribute, range)
        column = column_for_attribute(attribute)
        qualified_column = "#{table_name}.#{column.name}"
        parsed_range = Tag.parse_helper(range, column.type)

        add_range_relation(parsed_range, qualified_column)
      end

      def add_range_relation(arr, field)
        return all if arr.nil?

        case arr[0]
        when :eq
          if arr[1].is_a?(Time)
            where("#{field} between ? and ?", arr[1].beginning_of_day, arr[1].end_of_day)
          else
            where(["#{field} = ?", arr[1]])
          end
        when :gt
          where(["#{field} > ?", arr[1]])
        when :gte
          where(["#{field} >= ?", arr[1]])
        when :lt
          where(["#{field} < ?", arr[1]])
        when :lte
          where(["#{field} <= ?", arr[1]])
        when :in
          where(["#{field} in (?)", arr[1]])
        when :between
          where(["#{field} BETWEEN ? AND ?", arr[1], arr[2]])
        else
          all
        end
      end

      def text_attribute_matches(attribute, value, convert_to_wildcard: false)
        column = column_for_attribute(attribute)
        qualified_column = "#{table_name}.#{column.name}"
        value = "*#{value}*" if convert_to_wildcard && value.exclude?("*")

        if value =~ /\*/
          where("lower(#{qualified_column}) LIKE :value ESCAPE E'\\\\'", value: value.downcase.to_escaped_for_sql_like)
        else
          where("to_tsvector(:ts_config, #{qualified_column}) @@ plainto_tsquery(:ts_config, :value)", ts_config: "english", value: value)
        end
      end

      def apply_default_order(params)
        return default_order
      end

      def default_order
        order(id: :desc)
      end

      def search(params)
        params ||= {}

        q = all
        q = q.attribute_matches(:id, params[:id])
        q = q.attribute_matches(:created_at, params[:created_at]) if attribute_names.include?("created_at")
        q = q.attribute_matches(:updated_at, params[:updated_at]) if attribute_names.include?("updated_at")

        q
      end
    end
  end

  module ApiMethods
    extend ActiveSupport::Concern

    def as_json(options = {})
      options ||= {}
      options[:except] ||= []
      options[:except] += hidden_attributes

      options[:methods] ||= []
      options[:methods] += method_attributes

      super(options)
    end

    def serializable_hash(*args)
      hash = super(*args)
      hash.transform_keys { |key| key.delete("?") }
    end

    protected

    def hidden_attributes
      [:uploader_ip_addr, :updater_ip_addr, :creator_ip_addr, :user_ip_addr, :ip_addr]
    end

    def method_attributes
      []
    end
  end

  concerning :ActiveRecordExtensions do
    class_methods do
      def without_timeout
        connection.execute("SET STATEMENT_TIMEOUT = 0") unless Rails.env == "test"
        yield
      ensure
        connection.execute("SET STATEMENT_TIMEOUT = #{CurrentUser.user.try(:statement_timeout) || 3_000}") unless Rails.env == "test"
      end

      def with_timeout(n, default_value = nil, new_relic_params = {})
        connection.execute("SET STATEMENT_TIMEOUT = #{n}") unless Rails.env == "test"
        yield
      rescue ::ActiveRecord::StatementInvalid => x
        DanbooruLogger.log(x, expected: true)
        return default_value
      ensure
        connection.execute("SET STATEMENT_TIMEOUT = #{CurrentUser.user.try(:statement_timeout) || 3_000}") unless Rails.env == "test"
      end
    end
  end

  concerning :SimpleVersioningMethods do
    class_methods do
      def simple_versioning(options = {})
        cattr_accessor :versioning_body_column, :versioning_ip_column, :versioning_user_column, :versioning_subject_column
        self.versioning_body_column = options[:body_column] || "body"
        self.versioning_subject_column = options[:subject_column]
        self.versioning_ip_column = options[:ip_column] || "creator_ip_addr"
        self.versioning_user_column = options[:user_column] || "creator_id"

        class_eval do
          has_many :versions, class_name: 'EditHistory', as: :versionable
          after_update :save_version, if: :should_version_change

          define_method :should_version_change do
            if self.versioning_subject_column
              return true if send "saved_change_to_#{self.versioning_subject_column}?"
            end
            send "saved_change_to_#{self.versioning_body_column}?"
          end

          define_method :save_version do
            EditHistory.transaction do
              our_next_version = next_version
              if our_next_version == 0
                our_next_version += 1
                new = EditHistory.new
                new.versionable = self
                new.version = 1
                new.ip_addr = self.send self.versioning_ip_column
                new.body = self.send "#{self.versioning_body_column}_before_last_save"
                new.user_id = self.send self.versioning_user_column
                new.subject = self.send "#{self.versioning_subject_column}_before_last_save" if self.versioning_subject_column
                new.created_at = self.created_at
                new.save
              end

              version = EditHistory.new
              version.version = our_next_version + 1
              version.versionable = self
              version.ip_addr = CurrentUser.ip_addr
              version.body = self.send self.versioning_body_column
              version.user_id = CurrentUser.id
              version.save
            end
          end

          define_method :next_version do
            versions.count
          end
        end
      end
    end
  end

  concerning :UserMethods do
    class_methods do
      def user_status_counter(counter_name, options = {})
        class_eval do
          belongs_to :user_status, **{foreign_key: :creator_id, primary_key: :user_id, counter_cache: counter_name}.merge(options)
        end
      end

      def belongs_to_creator(options = {})
        class_eval do
          belongs_to :creator, **options.merge(class_name: "User")
          before_validation(on: :create) do |rec|
            if rec.creator_id.nil?
              rec.creator_id = CurrentUser.id
              rec.creator_ip_addr = CurrentUser.ip_addr if rec.respond_to?(:creator_ip_addr=)
            end
          end

          define_method :creator_name do
            User.id_to_name(creator_id)
          end
        end
      end

      def belongs_to_updater(options = {})
        class_eval do
          belongs_to :updater, **options.merge(class_name: "User")
          before_validation do |rec|
            rec.updater_id = CurrentUser.id
            rec.updater_ip_addr = CurrentUser.ip_addr if rec.respond_to?(:updater_ip_addr=)
          end

          define_method :updater_name do
            User.id_to_name(updater_id)
          end
        end
      end
    end
  end

  concerning :AttributeMethods do
    class_methods do
      # Defines `<attribute>_string`, `<attribute>_string=`, and `<attribute>=`
      # methods for converting an array attribute to or from a string.
      #
      # The `<attribute>=` setter parses strings into an array using the
      # `parse` regex. The resulting strings can be converted to another type
      # with the `cast` option.
      def array_attribute(name, parse: /[^[:space:]]+/, cast: :itself)
        define_method "#{name}_string" do
          send(name).join(" ")
        end

        define_method "#{name}_string=" do |value|
          raise ArgumentError, "#{name} must be a String" unless value.respond_to?(:to_str)
          send("#{name}=", value)
        end

        define_method "#{name}=" do |value|
          if value.respond_to?(:to_str)
            super value.to_str.scan(parse).flatten.map(&cast)
          elsif value.respond_to?(:to_a)
            super value.to_a
          else
            raise ArgumentError, "#{name} must be a String or an Array"
          end
        end
      end
    end
  end

  def warnings
    @warnings ||= ActiveModel::Errors.new(self)
  end

  include ApiMethods
end
