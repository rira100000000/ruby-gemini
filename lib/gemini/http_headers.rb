module Gemini
  module HTTPHeaders
    def add_headers(headers)
      @extra_headers = extra_headers.merge(headers.transform_keys(&:to_s))
    end

    private

    def headers
      default_headers.merge(extra_headers)
    end

    def default_headers
      {
        "Content-Type" => "application/json",
        "User-Agent" => "ruby-gemini-api/#{Gemini::VERSION}"
      }
    end

    def extra_headers
      @extra_headers ||= {}
    end
  end
end