module Gemini
  class Files
    # File APIのベースURL
    FILE_API_BASE_PATH = "files".freeze

    def initialize(client:)
      @client = client
    end

    # ファイルをアップロードするメソッド
    # @param file [File] アップロードするファイル
    # @param display_name [String] ファイルの表示名（オプション）
    # @return [Hash] アップロードされたファイルの情報
    def upload(file:, display_name: nil)
      # ファイルが有効かチェック
      raise ArgumentError, "ファイルが指定されていません" unless file

      # ファイルのMIMEタイプとサイズを取得
      mime_type = determine_mime_type(file)
      file.rewind
      file_size = file.size

      # display_nameが指定されていない場合はファイル名を使用
      display_name ||= File.basename(file.path) if file.respond_to?(:path)
      display_name ||= "uploaded_file"

      # 初期アップロードリクエスト（メタデータ定義）のヘッダー
      headers = {
        "X-Goog-Upload-Protocol" => "resumable",
        "X-Goog-Upload-Command" => "start",
        "X-Goog-Upload-Header-Content-Length" => file_size.to_s,
        "X-Goog-Upload-Header-Content-Type" => mime_type,
        "Content-Type" => "application/json"
      }

      # デバッグ出力を追加
      if ENV["DEBUG"]
        puts "リクエストURL: https://generativelanguage.googleapis.com/upload/v1beta/files"
        puts "ヘッダー: #{headers.inspect}"
        puts "APIキー: #{@client.api_key[0..5]}..." if @client.api_key
      end

      # 初期リクエストを送信してアップロードURLを取得
      response = @client.conn.post("https://generativelanguage.googleapis.com/upload/v1beta/files") do |req|
        req.headers = headers
        req.params = { key: @client.api_key }
        req.body = { file: { display_name: display_name } }.to_json
      end

      # レスポンスヘッダーからアップロードURLを取得
      upload_url = response.headers["x-goog-upload-url"]
      raise "アップロードURLを取得できませんでした" unless upload_url

      # ファイルをアップロード
      file.rewind
      file_data = file.read
      upload_response = @client.conn.post(upload_url) do |req|
        req.headers = {
          "Content-Length" => file_size.to_s,
          "X-Goog-Upload-Offset" => "0",
          "X-Goog-Upload-Command" => "upload, finalize"
        }
        req.body = file_data
      end

      # レスポンスをJSONとしてパース
      if upload_response.body.is_a?(String)
        JSON.parse(upload_response.body)
      elsif upload_response.body.is_a?(Hash)
        upload_response.body
      else
        raise "不正なレスポンス形式: #{upload_response.body.class}"
      end
    end

    # ファイルのメタデータを取得するメソッド
    # @param name [String] ファイル名（例: "files/abc-123"）
    # @return [Hash] ファイルのメタデータ
    def get(name:)
      path = name.start_with?("files/") ? name : "files/#{name}"
      @client.get(path: path)
    end

    # アップロードしたファイル一覧を取得するメソッド
    # @param page_size [Integer] 1ページあたりの最大ファイル数
    # @param page_token [String] 前回のリクエストで取得したページトークン
    # @return [Hash] ファイル一覧とページトークン
    def list(page_size: nil, page_token: nil)
      parameters = {}
      parameters[:pageSize] = page_size if page_size
      parameters[:pageToken] = page_token if page_token

      @client.get(
        path: FILE_API_BASE_PATH,
        parameters: parameters
      )
    end

    # ファイルを削除するメソッド
    # @param name [String] ファイル名（例: "files/abc-123"）
    # @return [Hash] 削除結果
    def delete(name:)
      path = name.start_with?("files/") ? name : "files/#{name}"
      @client.delete(path: path)
    end

    private

    # ファイルの拡張子からMIME typeを簡易判定
    def determine_mime_type(file)
      return "application/octet-stream" unless file.respond_to?(:path)

      ext = File.extname(file.path).downcase
      case ext
      when ".jpg", ".jpeg"
        "image/jpeg"
      when ".png"
        "image/png"
      when ".gif"
        "image/gif"
      when ".webp"
        "image/webp"
      when ".wav"
        "audio/wav"
      when ".mp3"
        "audio/mp3"
      when ".aiff"
        "audio/aiff"
      when ".aac"
        "audio/aac"
      when ".ogg"
        "audio/ogg"
      when ".flac"
        "audio/flac"
      when ".mp4"
        "video/mp4"
      when ".avi"
        "video/avi"
      when ".mov"
        "video/quicktime"
      when ".mkv"
        "video/x-matroska"
      when ".pdf"
        "application/pdf"
      when ".txt"
        "text/plain"
      when ".doc", ".docx"
        "application/msword"
      when ".xlsx", ".xls"
        "application/vnd.ms-excel"
      when ".pptx", ".ppt"
        "application/vnd.ms-powerpoint"
      else
        # デフォルト値
        "application/octet-stream"
      end
    end
  end
end