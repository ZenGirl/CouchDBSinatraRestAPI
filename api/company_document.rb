module Company
  class Document
    attr_accessor :id, :author_id, :owner_id, :created_at, :updated_at, :type, :_rev

    def initialize(author_id, owner_id)
      @id = nil
      @author_id, @owner_id = author_id, owner_id
      @created_at = Time.now
      @updated_at = Time.now
      @type = 'Company::Document'
    end

    @@ATTRIBUTE_TYPES = [
        {:author_id => 'String', :owner_id => 'String'}
    ]

    def self.input_attributes
      @@ATTRIBUTE_TYPES
    end

    def attributes
      attrs = []
      self.instance_variables.each do |var|
        attrs << var.to_s.gsub(/^@/, '')
      end
      attrs
    end

    def self.attributes
      new('', '').attributes
    end

    def errors
      errors = []
      errors << 'Must have author_id' if author_id.empty?
      errors << 'Must have owner_id' if owner_id.empty?
      errors
    end

    def valid?
      return true if errors.size <=0
      false
    end

    def load_from(params)
      attrs = attributes
      params.each_pair do |key, value|
        self.instance_variable_set('@'+key, value) if attrs.include? key
      end
      self
    end

    def to_json
      hash = {}
      self.instance_variables.each do |var|
        next if var.to_s == '@id'
        hash[var.to_s.gsub(/^@/, '')] = self.instance_variable_get var
      end
      hash.to_json
    end

    def from_json!(str)
      JSON.load(str).each do |key, value|
        next if %w(_revs_info).include? key
        self.instance_variable_set('@'+key, value)
      end
      self
    end

  end
end