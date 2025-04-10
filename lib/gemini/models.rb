module Gemini
  class Models
    def initialize(client:)
      @client = client
    end

    def list
      @client.get(path: "models")
    end

    def retrieve(id:)
      @client.get(path: "models/#{id}")
    end

    # Stub for compatibility, as Gemini API currently doesn't provide model deletion
    def delete(id:)
      raise NotImplementedError, "Model deletion is not supported in Gemini API"
    end
  end
end