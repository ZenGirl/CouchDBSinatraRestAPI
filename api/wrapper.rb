module Company
  class Wrapper
    attr_accessor :errors, :query, :body

    def initialize(errors, query, body)
      @errors, @query, @body = errors, query, body
    end

    def to_json
      h = {
          :errors => @errors,
          :query => @query,
          :body => @body
      }
      JSON.pretty_generate h
    end

  end
end
