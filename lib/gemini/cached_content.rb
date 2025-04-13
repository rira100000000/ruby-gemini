module Gemini
  class CachedContent
    def initialize(client:)
      @client = client
    end

    # コンテンツをキャッシュに保存
    def create(file_path: nil, file_uri: nil, system_instruction: nil, mime_type: nil, model: nil, ttl: "86400s", **parameters)
      # ファイルパスが指定されている場合はアップロード
      if file_path && !file_uri
        file = File.open(file_path, "rb")
        begin
          upload_result = @client.files.upload(file: file)
          file_uri = upload_result["file"]["uri"]
        ensure
          file.close
        end
      end
      
      # file_uriが必須
      raise ArgumentError, "file_uri parameter is required" unless file_uri
      
      # MIMEタイプを判定
      mime_type ||= file_path ? @client.determine_mime_type(file_path) : "application/octet-stream"
      
      # モデルを取得（models/プレフィックスを追加）
      model_name = model || parameters[:model] || "gemini-1.5-flash"
      model_name = "models/#{model_name}" unless model_name.start_with?("models/")
      
      # キャッシュリクエストを構築（キャメルケースに注意）
      request = {
        model: model_name,
        contents: [
          {
            parts: [
              { file_data: { mime_type: mime_type, file_uri: file_uri } }
            ],
            role: "user"
          }
        ],
        ttl: ttl
      }
      
      # システム指示が指定されている場合は追加（キャメルケースで指定）
      if system_instruction
        request[:systemInstruction] = {
          parts: [{ text: system_instruction }],
          role: "system"
        }
      end
      
      # その他のパラメータを追加（ただしmime_typeとmodelは除外）
      parameters.each do |key, value|
        next if [:mime_type, :model].include?(key)
        
        # スネークケースをキャメルケースに変換（必要に応じて）
        camel_key = key.to_s.gsub(/_([a-z])/) { $1.upcase }.to_sym
        request[camel_key] = value
      end
      
      # リクエストURLを直接構築
      full_url = "https://generativelanguage.googleapis.com/v1beta/cachedContents"
      
      # 直接Faradayを使用してリクエストを送信
      conn = @client.conn
      response = conn.post(full_url) do |req|
        # ここでheadersメソッドを直接使用するのではなく、Content-Typeを手動で設定
        req.headers = { 'Content-Type' => 'application/json' }
        req.params = { key: @client.api_key }
        req.body = request.to_json
      end
      
      parsed_response = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        response.body
      end
      
      Gemini::Response.new(parsed_response)
    end

    # キャッシュの一覧を取得
    def list(parameters: {})
      # パラメータをキャメルケースに変換
      camel_params = {}
      parameters.each do |key, value|
        camel_key = key.to_s.gsub(/_([a-z])/) { $1.upcase }
        camel_params[camel_key] = value
      end
      
      # 直接URLを構築
      full_url = "https://generativelanguage.googleapis.com/v1beta/cachedContents"
      
      # 直接Faradayを使用
      conn = @client.conn
      response = conn.get(full_url) do |req|
        # ここでheadersメソッドを直接使用するのではなく、Content-Typeを手動で設定
        req.headers = { 'Content-Type' => 'application/json' }
        req.params = camel_params.merge(key: @client.api_key)
      end
      
      parsed_response = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        response.body
      end
      
      Gemini::Response.new(parsed_response)
    end

    # キャッシュを更新
    def update(name:, ttl: "86400s")      
      full_url = "https://generativelanguage.googleapis.com/v1beta/#{name}"
      
      conn = @client.conn
      response = conn.patch(full_url) do |req|
        # ここでheadersメソッドを直接使用するのではなく、Content-Typeを手動で設定
        req.headers = { 'Content-Type' => 'application/json' }
        req.params = { key: @client.api_key }
        req.body = { ttl: ttl }.to_json
      end
      
      parsed_response = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        response.body
      end
      
      Gemini::Response.new(parsed_response)
    end

    def delete(name:)
      full_url = "https://generativelanguage.googleapis.com/v1beta/#{name}"
      
      conn = @client.conn
      response = conn.delete(full_url) do |req|
        # ここでheadersメソッドを直接使用するのではなく、Content-Typeを手動で設定
        req.headers = { 'Content-Type' => 'application/json' }
        req.params = { key: @client.api_key }
      end
      
      parsed_response = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        response.body
      end
      
      Gemini::Response.new(parsed_response)
    end
  end
end