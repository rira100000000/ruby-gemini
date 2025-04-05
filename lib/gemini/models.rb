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

    # Gemini APIでは現在モデル削除APIが提供されていないため互換性のためのスタブ
    def delete(id:)
      raise NotImplementedError, "Gemini APIではモデル削除機能は提供されていません"
    end
  end
end