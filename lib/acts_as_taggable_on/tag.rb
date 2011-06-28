module ActsAsTaggableOn
  class Tag < ::ActiveRecord::Base
    include ActsAsTaggableOn::ActiveRecord::Backports if ::ActiveRecord::VERSION::MAJOR < 3

    attr_accessible :name, :locale

    ### ASSOCIATIONS:

    has_many :taggings, :dependent => :destroy, :class_name => 'ActsAsTaggableOn::Tagging'

    ### VALIDATIONS:

    validates_presence_of :name, :locale
    validates_uniqueness_of :name, :scope => :locale

    ### SCOPES:

    def self.using_postgresql?
      connection.adapter_name == 'PostgreSQL'
    end

    def self.named(name, locale = "en")
      where(["name #{like_operator} ? AND locale = ?", name, locale])
    end

    def self.named_any(list, locale = "en")
      where(list.map { |tag| sanitize_sql(["name #{like_operator} ? AND locale = ?", tag.to_s, locale]) }.join(" OR "))
    end

    def self.named_like(name, locale = "en")
      where(["name #{like_operator} ? AND locale = ?", "%#{name}%", locale])
    end

    def self.named_like_any(list, locale = "en")
      where(list.map { |tag| sanitize_sql(["name #{like_operator} ? AND locale = ?", "%#{tag.to_s}%", locale]) }.join(" OR "))
    end

    ### CLASS METHODS:

    def self.find_or_create_with_like_by_name(name, locale = "en")
      named_like(name, locale).first || create(:name => name, :locale => locale)
    end

    def self.find_or_create_all_with_like_by_name(*list, locale = "en")
      list = [list].flatten

      return [] if list.empty?

      existing_tags = Tag.named_any(list, locale).all
      new_tag_names = list.reject do |name| 
        name = comparable_name(name)
        existing_tags.any? { |tag| comparable_name(tag.name) == name }
      end
      created_tags  = new_tag_names.map { |name| Tag.create(:name => name, :locale => locale) }

      existing_tags + created_tags
    end

    ### INSTANCE METHODS:

    def ==(object)
      super || (object.is_a?(Tag) && name == object.name && locale == object.locale)
    end

    def to_s
      name
    end

    def count
      read_attribute(:count).to_i
    end

    class << self
      private
      def like_operator
        using_postgresql? ? 'ILIKE' : 'LIKE'
      end

      def comparable_name(str)
        RUBY_VERSION >= "1.9" ? str.downcase : str.mb_chars.downcase
      end
    end
  end
end
