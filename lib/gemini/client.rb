module Gemini
  class Client
    include Gemini::HTTP
    
    SENSITIVE_ATTRIBUTES = %i[@api_key @extra_headers].freeze
    CONFIG_KEYS = %i[api_key uri_base extra_headers log_errors request_timeout].freeze
    
    attr_reader(*CONFIG_KEYS, :faraday_middleware)
    attr_writer :api_key
    
    def initialize(api_key = nil, config = {}, &faraday_middleware)
      # APIキーが直接引数として渡された場合の処理
      config[:api_key] = api_key if api_key
      
      CONFIG_KEYS.each do |key|
        # インスタンス変数を設定。設定がなければグローバル設定を使用
        instance_variable_set(
          "@#{key}",
          config[key].nil? ? Gemini.configuration.send(key) : config[key]
        )
      end
      
      @api_key ||= ENV["GEMINI_API_KEY"]
      @faraday_middleware = faraday_middleware
      
      raise ConfigurationError, "API キーが設定されていません" unless @api_key
    end
    
    # スレッド管理へのアクセサ
    def threads
      @threads ||= Gemini::Threads.new(client: self)
    end
    
    # メッセージ管理へのアクセサ
    def messages
      @messages ||= Gemini::Messages.new(client: self)
    end
    
    # 実行管理へのアクセサ
    def runs
      @runs ||= Gemini::Runs.new(client: self)
    end
    
    # OpenAIの chat に似た、Gemini APIのテキスト生成メソッド
    def chat(parameters: {})
      model = parameters.delete(:model) || "gemini-2.0-flash-lite"
      path = "models/#{model}:generateContent"
      json_post(path: path, parameters: parameters)
    end
    
    # OpenAIの embeddings に対応するメソッド
    def embeddings(parameters: {})
      model = parameters.delete(:model) || "text-embedding-model"
      path = "models/#{model}:embedContent"
      json_post(path: path, parameters: parameters)
    end
    
    # OpenAIの completions に対応するメソッド
    # Gemini APIでは chat と同じエンドポイントを使用
    def completions(parameters: {})
      chat(parameters: parameters)
    end
    
    # サブクライアントへのアクセサ
    def models
      @models ||= Gemini::Models.new(client: self)
    end
    
    # 利便性のためのヘルパーメソッド
    
    # OpenAIの chat に似た使い方ができるメソッド
    def generate_content(prompt, model: "gemini-2.0-flash-lite", **parameters)
      content = format_content(prompt)
      params = {
        contents: [content],
        model: model
      }.merge(parameters)
      
      chat(parameters: params)
    end
    
    # ストリーミングテキスト生成
    def generate_content_stream(prompt, model: "gemini-2.0-flash-lite", **parameters, &block)
      raise ArgumentError, "ストリーミングにはブロックが必要です" unless block_given?
      
      content = format_content(prompt)
      params = {
        contents: [content],
        model: model,
        stream: block
      }.merge(parameters)
      
      path = "models/#{model}:streamGenerateContent"
      json_post(path: path, parameters: params)
    end

    # デバッグ用のinspectメソッド
    def inspect
      vars = instance_variables.map do |var|
        value = instance_variable_get(var)
        SENSITIVE_ATTRIBUTES.include?(var) ? "#{var}=[REDACTED]" : "#{var}=#{value.inspect}"
      end
      "#<#{self.class}:#{object_id} #{vars.join(', ')}>"
    end
    
    private
    
    # 入力をGemini API形式に変換
    def format_content(input)
      case input
      when String
        { parts: [{ text: input }] }
      when Array
        if input.all? { |part| part.is_a?(Hash) && part.key?(:text) }
          { parts: input }
        else
          { parts: input.map { |text| { text: text.to_s } } }
        end
      when Hash
        input
      else
        { parts: [{ text: input.to_s }] }
      end
    end
  end
end