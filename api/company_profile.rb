module Company
  class Profile
    attr_accessor :first_name, :last_name, :handle, :title, :bio, :primary_email, :primary_phone

    def initialize(first_name, last_name, handle, title, bio, primary_email, primary_phone)
      @id = nil
      @first_name, @last_name, @handle, @title, @bio, @primary_email, @primary_phone = first_name, last_name, handle, title, bio, primary_email, primary_phone
      @type = 'Company::Profile'
    end

    def to_json
      hash = {}
      self.instance_variables.each do |var|
        next if var.to_s == '@id'
        p "Assigning [#{var.to_s.gsub(/^@/,'')}] [#{self.instance_variable_get var}]"
        hash[var.to_s.gsub(/^@/,'')] = self.instance_variable_get var
      end
      hash.to_json
    end

    def from_json! string
      JSON.load(string).each do |var, val|
        self.instance_variable_set var, val
      end
    end

  end
end