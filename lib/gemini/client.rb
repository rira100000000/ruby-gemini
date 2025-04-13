module Gemini
  class Client
    include Gemini::HTTP
    
    SENSITIVE_ATTRIBUTES = %i[@api_key @extra_headers].freeze
    CONFIG_KEYS = %i[api_key uri_base extra_headers log_errors request_timeout].freeze
    
    attr_reader(*CONFIG_KEYS, :faraday_middleware)
    attr_writer :api_key
    
    def initialize(api_key = nil, config = {}, &faraday_middleware)
      # Handle API key passed directly as argument
      config[:api_key] = api_key if api_key
      
      CONFIG_KEYS.each do |key|
        # Set instance variables. Use global config if no setting provided
        instance_variable_set(
          "@#{key}",
          config[key].nil? ? Gemini.configuration.send(key) : config[key]
        )
      end
      
      @api_key ||= ENV["GEMINI_API_KEY"]
      @faraday_middleware = faraday_middleware
      
      raise ConfigurationError, "API key is not set" unless @api_key
    end
    
    # Thread management accessor
    def threads
      @threads ||= Gemini::Threads.new(client: self)
    end
    
    # Message management accessor
    def messages
      @messages ||= Gemini::Messages.new(client: self)
    end
    
    # Run management accessor
    def runs
      @runs ||= Gemini::Runs.new(client: self)
    end

    def audio
      @audio ||= Gemini::Audio.new(client: self)
    end

    def files
      @files ||= Gemini::Files.new(client: self)
    end

    # 画像生成アクセサ
    def images
      @images ||= Gemini::Images.new(client: self)
    end

    # ドキュメント処理アクセサ
    def documents
      @documents ||= Gemini::Documents.new(client: self)
    end

    # キャッシュ管理アクセサ
    def cached_content
      @cached_content ||= Gemini::CachedContent.new(client: self)
    end

    def reset_headers
      @extra_headers = {}
    end
    
    # Access to conn (Faraday connection) for Audio features
    # Wrapper to allow using private methods from HTTP module externally
    def conn(multipart: false)
      super(multipart: multipart)
    end
    
    # OpenAI chat-like text generation method for Gemini API
    # Extended to support streaming callbacks
    def chat(parameters: {}, &stream_callback)
      model = parameters.delete(:model) || "gemini-2.0-flash-lite"
      
      # If streaming callback is provided
      if block_given?
        path = "models/#{model}:streamGenerateContent"
        # Set up stream callback
        stream_params = parameters.dup
        stream_params[:stream] = proc { |chunk| process_stream_chunk(chunk, &stream_callback) }
        response = json_post(path: path, parameters: stream_params)
        return Gemini::Response.new(response)
      else
        # Normal batch response mode
        path = "models/#{model}:generateContent"
        response = json_post(path: path, parameters: parameters)
        return Gemini::Response.new(response)
      end
    end
    
    # Method corresponding to OpenAI's embeddings
    def embeddings(parameters: {})
      model = parameters.delete(:model) || "text-embedding-model"
      path = "models/#{model}:embedContent"
      response = json_post(path: path, parameters: parameters)
      Gemini::Response.new(response)
    end
    
    # Method corresponding to OpenAI's completions
    # Uses same endpoint as chat in Gemini API
    def completions(parameters: {}, &stream_callback)
      chat(parameters: parameters, &stream_callback)
    end
    
    # Accessor for sub-clients
    def models
      @models ||= Gemini::Models.new(client: self)
    end
    
    # Helper methods for convenience
    
    # Method with usage similar to OpenAI's chat
    def generate_content(prompt, model: "gemini-2.0-flash-lite", system_instruction: nil, 
                        response_mime_type: nil, response_schema: nil, **parameters, &stream_callback)
      # For image/text combinations, the prompt is passed as an array
      # example: [{type: "text", text: "What is this?"}, {type: "image_url", image_url: {url: "https://example.com/image.jpg"}}]
      content = format_content(prompt)
      params = {
        contents: [content],
        model: model
      }
      
      if system_instruction
        params[:system_instruction] = format_content(system_instruction)
      end
      
      if response_mime_type || response_schema
        params[:generation_config] ||= {}
        
        if response_mime_type
          params[:generation_config]["response_mime_type"] = response_mime_type
        end
        
        if response_schema
          params[:generation_config]["response_schema"] = response_schema
        end
      end
      
      # Merge other parameters
      params.merge!(parameters)
      
      if block_given?
        chat(parameters: params, &stream_callback)
      else
        chat(parameters: params)
      end
    end

    # Streaming text generation
    def generate_content_stream(prompt, model: "gemini-2.0-flash-lite", system_instruction: nil,
                              response_mime_type: nil, response_schema: nil, **parameters, &block)
      raise ArgumentError, "Block is required for streaming" unless block_given?
      
      content = format_content(prompt)
      params = {
        contents: [content],
        model: model
      }
      
      if system_instruction
        params[:system_instruction] = format_content(system_instruction)
      end
      
      if response_mime_type || response_schema
        params[:generation_config] ||= {}
        
        if response_mime_type
          params[:generation_config][:response_mime_type] = response_mime_type
        end
        
        if response_schema
          params[:generation_config][:response_schema] = response_schema
        end
      end
      
      # Merge other parameters
      params.merge!(parameters)
      
      chat(parameters: params, &block)
    end

    # ファイルを使った会話（複数ファイル対応）
    def chat_with_multimodal(file_paths, prompt, model: "gemini-1.5-flash", **parameters)
      # スレッドを作成
      thread = threads.create(parameters: { model: model })
      thread_id = thread["id"]
      
      # 複数のファイルをアップロードして追加
      file_infos = []
      
      begin
        # ファイルをアップロードしてメッセージとして追加
        file_paths.each do |file_path|
          file = File.open(file_path, "rb")
          begin
            upload_result = files.upload(file: file)
            file_uri = upload_result["file"]["uri"]
            file_name = upload_result["file"]["name"]
            mime_type = determine_mime_type(file_path)
            
            # ファイル情報を保存
            file_infos << {
              uri: file_uri,
              name: file_name,
              mime_type: mime_type
            }
            
            # ファイルをメッセージとして追加
            messages.create(
              thread_id: thread_id,
              parameters: {
                role: "user",
                content: [
                  { file_data: { mime_type: mime_type, file_uri: file_uri } }
                ]
              }
            )
          ensure
            file.close
          end
        end
        
        # プロンプトメッセージを追加
        messages.create(
          thread_id: thread_id,
          parameters: {
            role: "user",
            content: prompt
          }
        )
        
        # 実行
        run = runs.create(thread_id: thread_id, parameters: parameters)
        
        # メッセージを取得
        messages_list = messages.list(thread_id: thread_id)
        
        # 結果とファイル情報を返す
        {
          messages: messages_list,
          run: run,
          file_infos: file_infos,
          thread_id: thread_id
        }
      rescue => e
        # エラー処理
        { error: e.message, file_infos: file_infos }
      end
    end

    def generate_content_with_cache(prompt, cached_content:, model: "gemini-1.5-flash", **parameters)
      # モデル名にmodels/プレフィックスを追加
      model_name = model.start_with?("models/") ? model : "models/#{model}"
      
      # リクエストパラメータを構築
      params = {
        contents: [
          {
            parts: [{ text: prompt }],
            role: "user"
          }
        ],
        cachedContent: cached_content
      }
      
      # その他のパラメータをマージ
      params.merge!(parameters)
      
      # 直接エンドポイントURLを構築
      endpoint = "#{model_name}:generateContent"
      
      # APIリクエスト
      response = json_post(
        path: endpoint,
        parameters: params
      )
      
      Gemini::Response.new(response)
    end

    # 単一ファイルのヘルパー
    def chat_with_file(file_path, prompt, model: "gemini-1.5-flash", **parameters)
      chat_with_multimodal([file_path], prompt, model: model, **parameters)
    end

    # ファイルをアップロードして質問するシンプルなヘルパー
    def upload_and_process_file(file_path, prompt, content_type: nil, model: "gemini-1.5-flash", **parameters)
      # MIMEタイプを自動判定
      mime_type = content_type || determine_mime_type(file_path)
      
      # ファイルをアップロード
      file = File.open(file_path, "rb")
      begin
        upload_result = files.upload(file: file)
        file_uri = upload_result["file"]["uri"]
        file_name = upload_result["file"]["name"]
        
        # コンテンツを生成
        response = generate_content(
          [
            { text: prompt },
            { file_data: { mime_type: mime_type, file_uri: file_uri } }
          ],
          model: model,
          **parameters
        )
        
        # レスポンスと一緒にファイル情報も返す
        {
          response: response,
          file_uri: file_uri,
          file_name: file_name
        }
      ensure
        file.close
      end
    end
    
    # Debug inspect method
    def inspect
      vars = instance_variables.map do |var|
        value = instance_variable_get(var)
        SENSITIVE_ATTRIBUTES.include?(var) ? "#{var}=[REDACTED]" : "#{var}=#{value.inspect}"
      end
      "#<#{self.class}:#{object_id} #{vars.join(', ')}>"
    end
    
    # MIMEタイプを判定するメソッド（パブリックに変更）
    def determine_mime_type(path_or_url)
      extension = File.extname(path_or_url).downcase
      
      # ドキュメント形式
      document_types = {
        ".pdf" => "application/pdf",
        ".js" => "application/x-javascript",
        ".py" => "application/x-python",
        ".txt" => "text/plain",
        ".html" => "text/html",
        ".htm" => "text/html",
        ".css" => "text/css",
        ".md" => "text/md",
        ".csv" => "text/csv",
        ".xml" => "text/xml",
        ".rtf" => "text/rtf"
      }
      
      # 画像形式
      image_types = {
        ".jpg" => "image/jpeg",
        ".jpeg" => "image/jpeg",
        ".png" => "image/png",
        ".gif" => "image/gif",
        ".webp" => "image/webp",
        ".heic" => "image/heic",
        ".heif" => "image/heif"
      }
      
      # 音声形式
      audio_types = {
        ".wav" => "audio/wav",
        ".mp3" => "audio/mp3",
        ".aiff" => "audio/aiff",
        ".aac" => "audio/aac",
        ".ogg" => "audio/ogg",
        ".flac" => "audio/flac"
      }
      
      # 拡張子からMIMEタイプを判定
      mime_type = document_types[extension] || image_types[extension] || audio_types[extension]
      return mime_type if mime_type
      
      # ファイルの内容から判定を試みる
      if File.exist?(path_or_url)
        # ファイルの最初の数バイトを読み込んで判定
        first_bytes = File.binread(path_or_url, 8).bytes
        case
        when first_bytes[0..1] == [0xFF, 0xD8]
          return "image/jpeg"  # JPEG
        when first_bytes[0..7] == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
          return "image/png"   # PNG
        when first_bytes[0..2] == [0x47, 0x49, 0x46]
          return "image/gif"   # GIF
        when first_bytes[0..3] == [0x52, 0x49, 0x46, 0x46] && first_bytes[8..11] == [0x57, 0x45, 0x42, 0x50]
          return "image/webp"  # WEBP
        when first_bytes[0..3] == [0x25, 0x50, 0x44, 0x46]
          return "application/pdf" # PDF
        when first_bytes[0..1] == [0x49, 0x44]
          return "audio/mp3"   # MP3
        when first_bytes[0..3] == [0x52, 0x49, 0x46, 0x46]
          return "audio/wav"   # WAV
        end
      end
      
      # URLまたは判定できない場合
      if path_or_url.start_with?("http://", "https://")
        "application/octet-stream"
      else
        "application/octet-stream"
      end
    end
    
    private
    
    # Process stream chunk and pass to callback
    def process_stream_chunk(chunk, &callback)
      if chunk.respond_to?(:dig) && chunk.dig("candidates", 0, "content", "parts", 0, "text")
        chunk_text = chunk.dig("candidates", 0, "content", "parts", 0, "text")
        callback.call(chunk_text, chunk)
      elsif chunk.respond_to?(:dig) && chunk.dig("candidates", 0, "content", "parts")
        # Pass empty part to callback if no text
        callback.call("", chunk)
      else
        # Treat other chunk types (metadata, etc.) as empty string
        callback.call("", chunk)
      end
    end
    
    # Convert input to Gemini API format with support for image inputs and file data
    def format_content(input)
      case input
      when String
        { parts: [{ text: input }] }
      when Array
        # For arrays, convert each element to part form
        processed_parts = input.map do |part|
          if part.is_a?(Hash)
            if part[:type]
              case part[:type]
              when "text"
                { text: part[:text] }
              when "image_url"
                # Convert to Gemini API format
                { 
                  inline_data: {
                    mime_type: determine_mime_type(part[:image_url][:url]),
                    data: encode_image_from_url(part[:image_url][:url])
                  }
                }
              when "image_file"
                {
                  inline_data: {
                    mime_type: determine_mime_type(part[:image_file][:file_path]),
                    data: encode_image_from_file(part[:image_file][:file_path])
                  }
                }
              when "image_base64"
                {
                  inline_data: {
                    mime_type: part[:image_base64][:mime_type],
                    data: part[:image_base64][:data]
                  }
                }
              when "file_data"
                # Support for uploaded files via file_data
                {
                  file_data: part[:file_data]
                }
              # 新しいタイプを追加
              when "document"
                {
                  file_data: {
                    mime_type: part[:document][:mime_type] || determine_mime_type(part[:document][:file_path]),
                    file_uri: part[:document][:file_uri]
                  }
                }
              when "audio"
                {
                  file_data: {
                    mime_type: part[:audio][:mime_type] || determine_mime_type(part[:audio][:file_path]),
                    file_uri: part[:audio][:file_uri]
                  }
                }
              else
                # Other types return as is
                part
              end
            elsif part[:file_data]
              # Direct file_data reference without type (for compatibility)
              {
                file_data: part[:file_data]
              }
            elsif part[:inline_data]
              # Direct inline_data reference without type
              {
                inline_data: part[:inline_data]
              }
            elsif part[:text]
              # Direct text reference without type
              { text: part[:text] }
            else
              # Return hash as is if no recognized keys
              part
            end
          elsif part.respond_to?(:to_s)
            { text: part.to_s }
          else
            part
          end
        end
        { parts: processed_parts }
      when Hash
        if input.key?(:parts)
          input  # If already in proper format, return as is
        else
          { parts: [input] }  # Wrapping the hash in parts
        end
      else
        { parts: [{ text: input.to_s }] }
      end
    end

    def encode_image_from_url(url)
      require 'open-uri'
      require 'base64'
      begin
        # Explicitly read in binary mode
        data = URI.open(url, 'rb').read
        Base64.strict_encode64(data)
      rescue => e
        raise Error.new("Failed to load image from URL: #{e.message}")
      end
    end

    def encode_image_from_file(file_path)
      require 'base64'
      begin
        Base64.strict_encode64(File.binread(file_path))
      rescue => e
        raise Error.new("Failed to load image from file: #{e.message}")
      end
    end
  end
end