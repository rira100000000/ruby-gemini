module Gemini
  class Embeddings
    def initialize(client:)
      @client = client
    end

    def create(input:, model: "text-embedding-model", **parameters)
      content = case input
                when String
                  { parts: [{ text: input }] }
                when Array
                  { parts: input.map { |text| { text: text.to_s } } }
                else
                  { parts: [{ text: input.to_s }] }
                end
      
      payload = {
        content: content
      }.merge(parameters)
      
      @client.json_post(
        path: "models/#{model}:embedContent",
        parameters: payload
      )
    end
  end
end