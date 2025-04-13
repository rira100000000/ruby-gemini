module Gemini
  class Documents
    def initialize(client:)
      @client = client
    end

    # ドキュメントをアップロードして質問する基本メソッド
    def process(file: nil, file_path: nil, prompt:, model: "gemini-1.5-flash", **parameters)
      # ファイルパスが指定されている場合はファイルを開く
      if file_path && !file
        file = File.open(file_path, "rb")
        close_file = true
      else
        close_file = false
      end

      begin
        # ファイルが指定されていない場合はエラー
        raise ArgumentError, "file or file_path parameter is required" unless file

        # MIMEタイプを判定
        mime_type = parameters[:mime_type] || determine_document_mime_type(file)
        
        # ファイルをアップロード
        upload_result = @client.files.upload(file: file)
        file_uri = upload_result["file"]["uri"]
        file_name = upload_result["file"]["name"]
        
        # コンテンツを生成
        response = @client.generate_content(
          [
            { text: prompt },
            { file_data: { mime_type: mime_type, file_uri: file_uri } }
          ],
          model: model,
          **parameters.reject { |k, _| [:mime_type].include?(k) }
        )
        
        # レスポンスと一緒にファイル情報も返す
        {
          response: response,
          file_uri: file_uri,
          file_name: file_name
        }
      ensure
        file.close if file && close_file
      end
    end

    # ドキュメントをキャッシュに保存するメソッド
    def cache(file: nil, file_path: nil, system_instruction: nil, ttl: "86400s", **parameters)
      # ファイルパスが指定されている場合はファイルを開く
      if file_path && !file
        file = File.open(file_path, "rb")
        close_file = true
      else
        close_file = false
      end

      begin
        # ファイルが指定されていない場合はエラー
        raise ArgumentError, "file or file_path parameter is required" unless file

        # MIMEタイプを判定
        mime_type = parameters[:mime_type] || determine_document_mime_type(file)
        
        # ファイルをアップロード
        upload_result = @client.files.upload(file: file)
        file_uri = upload_result["file"]["uri"]
        file_name = upload_result["file"]["name"]
        
        # モデル名の取得と調整
        model = parameters[:model] || "gemini-1.5-flash"
        model = "models/#{model}" unless model.start_with?("models/")
        
        # キャッシュに保存（パラメータの名前に注意）
        cache_result = @client.cached_content.create(
          file_uri: file_uri,
          mime_type: mime_type,
          system_instruction: system_instruction,
          model: model,
          ttl: ttl,
          **parameters.reject { |k, _| [:mime_type, :model].include?(k) }
        )
        
        # 結果とファイル情報を返す
        {
          cache: cache_result,
          file_uri: file_uri,
          file_name: file_name
        }
      ensure
        file.close if file && close_file
      end
    end

    private

    # ドキュメントのMIMEタイプを判定するヘルパーメソッド
    def determine_document_mime_type(file)
      return "application/octet-stream" unless file.respond_to?(:path)

      ext = File.extname(file.path).downcase
      case ext
      when ".pdf"
        "application/pdf"
      when ".js"
        "application/x-javascript"
      when ".py"
        "application/x-python"
      when ".txt"
        "text/plain"
      when ".html", ".htm"
        "text/html"
      when ".css"
        "text/css"
      when ".md"
        "text/md"
      when ".csv"
        "text/csv"
      when ".xml"
        "text/xml"
      when ".rtf"
        "text/rtf"
      else
        # PDFのマジックナンバーを確認
        file.rewind
        header = file.read(4)
        file.rewind
        
        # PDFのシグネチャ: %PDF
        if header && header.bytes.to_a[0..3] == [37, 80, 68, 70]
          return "application/pdf"
        end
        
        # デフォルト
        "application/octet-stream"
      end
    end
  end
end