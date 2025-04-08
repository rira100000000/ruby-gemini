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

    def audio
      @audio ||= Gemini::Audio.new(client: self)
    end

    def reset_headers
      @extra_headers = {}
    end
    
    # Audio機能用のconn（Faraday接続）へのアクセス
    # HTTPモジュールのprivateメソッドを外部から使用できるようにするためのラッパー
    def conn(multipart: false)
      super(multipart: multipart)
    end
    
    # OpenAIの chat に似た、Gemini APIのテキスト生成メソッド
    # ストリーミングコールバックにも対応するように拡張
    def chat(parameters: {}, &stream_callback)
      model = parameters.delete(:model) || "gemini-2.0-flash-lite"
      
      # ストリーミングコールバックが渡された場合
      if block_given?
        path = "models/#{model}:streamGenerateContent"
        # ストリームコールバックを設定
        stream_params = parameters.dup
        stream_params[:stream] = proc { |chunk| process_stream_chunk(chunk, &stream_callback) }
        return json_post(path: path, parameters: stream_params)
      else
        # 通常の一括レスポンスモード
        path = "models/#{model}:generateContent"
        return json_post(path: path, parameters: parameters)
      end
    end
    
    # OpenAIの embeddings に対応するメソッド
    def embeddings(parameters: {})
      model = parameters.delete(:model) || "text-embedding-model"
      path = "models/#{model}:embedContent"
      json_post(path: path, parameters: parameters)
    end
    
    # OpenAIの completions に対応するメソッド
    # Gemini APIでは chat と同じエンドポイントを使用
    def completions(parameters: {}, &stream_callback)
      chat(parameters: parameters, &stream_callback)
    end
    
    # サブクライアントへのアクセサ
    def models
      @models ||= Gemini::Models.new(client: self)
    end
    
    # 利便性のためのヘルパーメソッド
    
    # OpenAIの chat に似た使い方ができるメソッド
    # ストリーミングコールバックにも対応
    # system_instructionパラメータを追加
    def generate_content(prompt, model: "gemini-2.0-flash-lite", system_instruction: nil, **parameters, &stream_callback)
      content = format_content(prompt)
      params = {
        contents: [content],
        model: model
      }
      
      # system_instructionが提供された場合、それを追加
      if system_instruction
        params[:system_instruction] = format_content(system_instruction)
      end
      
      # 他のパラメータをマージ
      params.merge!(parameters)
      
      if block_given?
        chat(parameters: params, &stream_callback)
      else
        chat(parameters: params)
      end
    end
    
    # ストリーミングテキスト生成
    # 上記のgenerate_contentでも同じ機能を提供、こちらは明示的にstreamingを指定している
    # system_instructionパラメータを追加
    def generate_content_stream(prompt, model: "gemini-2.0-flash-lite", system_instruction: nil, **parameters, &block)
      raise ArgumentError, "ストリーミングにはブロックが必要です" unless block_given?
      
      content = format_content(prompt)
      params = {
        contents: [content],
        model: model
      }
      
      # system_instructionが提供された場合、それを追加
      if system_instruction
        params[:system_instruction] = format_content(system_instruction)
      end
      
      # 他のパラメータをマージ
      params.merge!(parameters)
      
      chat(parameters: params, &block)
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
    
    # ストリームチャンクを処理してコールバックに渡す
    def process_stream_chunk(chunk, &callback)
      if chunk.respond_to?(:dig) && chunk.dig("candidates", 0, "content", "parts", 0, "text")
        chunk_text = chunk.dig("candidates", 0, "content", "parts", 0, "text")
        callback.call(chunk_text, chunk)
      elsif chunk.respond_to?(:dig) && chunk.dig("candidates", 0, "content", "parts")
        # テキストがない場合は空の部分をコールバックに渡す
        callback.call("", chunk)
      else
        # その他の種類のチャンク（メタデータなど）は空文字列として扱う
        callback.call("", chunk)
      end
    end
    
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