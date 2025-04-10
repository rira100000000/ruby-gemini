module Gemini
  class Audio
    def initialize(client:)
      @client = client
    end

    # 音声ファイルから文字起こしを行う
    # @param parameters [Hash] パラメータ
    #   - file: 直接アップロードする音声ファイル（File）
    #   - file_uri: 事前にアップロードされたファイルのURI
    #   - model: 使用するモデル名（デフォルト: "gemini-1.5-flash"）
    #   - language: 言語コード（例: "ja"）
    #   - content_text: 文字起こし指示のテキスト
    # @return [Hash] 文字起こし結果
    def transcribe(parameters: {})
      file = parameters.delete(:file)
      file_uri = parameters.delete(:file_uri)
      model = parameters.delete(:model) || "gemini-1.5-flash"
      language = parameters.delete(:language)
      content_text = parameters.delete(:content_text) || "Transcribe this audio clip"
      
      # ファイルかfile_uriのどちらかが必要
      if !file && !file_uri
        raise ArgumentError, "音声ファイル（file）またはファイルURI（file_uri）が指定されていません"
      end

      # ファイルURIが指定されている場合はFile APIを使用
      if file_uri
        return transcribe_with_file_uri(file_uri, model, language, content_text, parameters)
      end
      
      # 直接ファイルをアップロードする場合
      # MIME typeの取得（簡易判定）
      mime_type = determine_mime_type(file)

      # ファイルのBase64エンコード
      file.rewind
      require 'base64'
      file_data = Base64.strict_encode64(file.read)
      
      # 文字起こしリクエストの言語設定
      if language
        content_text += " in #{language}"
      end
      
      # リクエストパラメータ構築
      request_params = {
        contents: [{
          parts: [
            { text: content_text },
            { 
              inline_data: { 
                mime_type: mime_type,
                data: file_data
              } 
            }
          ]
        }]
      }
      
      # 追加パラメータをマージ（contents以外をトップレベルに追加）
      parameters.each do |key, value|
        request_params[key] = value unless key == :contents
      end
      
      # generateContentリクエストを送信
      response = @client.json_post(
        path: "models/#{model}:generateContent",
        parameters: request_params
      )
      
      # レスポンスをフォーマット
      format_response(response)
    end
    
    private

    # 事前にアップロードされたファイルURIを使って文字起こしを行う
    def transcribe_with_file_uri(file_uri, model, language, content_text, parameters)
      # 文字起こしリクエストの言語設定
      if language
        content_text += " in #{language}"
      end
      
      # リクエストパラメータ構築
      request_params = {
        contents: [{
          parts: [
            { text: content_text },
            { 
              file_data: { 
                mime_type: "audio/mp3", # URIからはMIMEタイプを推測できないのでデフォルト値を使用
                file_uri: file_uri
              } 
            }
          ]
        }]
      }
      
      # 追加パラメータをマージ（contents以外をトップレベルに追加）
      parameters.each do |key, value|
        request_params[key] = value unless key == :contents
      end
      
      # generateContentリクエストを送信
      response = @client.json_post(
        path: "models/#{model}:generateContent",
        parameters: request_params
      )
      
      # レスポンスをフォーマット
      format_response(response)
    end
    
    # ファイルの拡張子からMIME typeを簡易判定
    def determine_mime_type(file)
      return "application/octet-stream" unless file.respond_to?(:path)

      ext = File.extname(file.path).downcase
      case ext
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
      else
        # デフォルト値（mp3と仮定）
        "audio/mp3"
      end
    end
    
    # Gemini APIのレスポンスをOpenAI形式に整形
    def format_response(response)
      # レスポンスからテキスト部分を抽出
      if response["candidates"] && !response["candidates"].empty?
        candidate = response["candidates"][0]
        if candidate["content"] && candidate["content"]["parts"] && !candidate["content"]["parts"].empty?
          text = candidate["content"]["parts"][0]["text"]
          
          # OpenAI形式のレスポンス
          return {
            "text" => text,
            "raw_response" => response # 元のレスポンスも含める
          }
        end
      end
      
      # テキストが見つからない場合は空のレスポンスを返す
      { "text" => "", "raw_response" => response }
    end
  end
end