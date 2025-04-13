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
      
      # モデルを取得
      model ||= parameters[:model] || "gemini-1.5-flash"
      
      # キャッシュリクエストを構築
      request = {
        model: model,
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
      
      # システム指示が指定されている場合は追加
      if system_instruction
        request[:system_instruction] = {
          parts: [{ text: system_instruction }],
          role: "system"
        }
      end
      
      # その他のパラメータを追加
      parameters.each do |key, value|
        request[key] = value unless [:mime_type, :model].include?(key)
      end
      
      # APIリクエスト
      response = @client.json_post(
        path: "v1beta/cachedContents",
        parameters: request
      )
      
      Gemini::Response.new(response)
    end

    # キャッシュの一覧を取得
    def list(parameters: {})
      response = @client.get(
        path: "v1beta/cachedContents",
        parameters: parameters
      )
      
      Gemini::Response.new(response)
    end

    # キャッシュを更新
    def update(name:, ttl: "86400s")
      response = @client.json_post(
        path: "v1beta/#{name}",
        parameters: { ttl: ttl },
        query_parameters: { method: "PATCH" }
      )
      
      Gemini::Response.new(response)
    end

    # キャッシュを削除
    def delete(name:)
      response = @client.delete(path: "v1beta/#{name}")
      
      Gemini::Response.new(response)
    end
  end
end