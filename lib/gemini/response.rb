module Gemini
  class Response
    # Raw response data from API
    attr_reader :raw_data
    
    def initialize(response_data)
      @raw_data = response_data
    end
    
    # Get simple text response (combines multiple parts if present)
    def text
      return nil unless valid?
      
      first_candidate&.dig("content", "parts")
        &.select { |part| part.key?("text") }
        &.map { |part| part["text"] }
        &.join("\n") || ""
    end
    
    # Get formatted text (HTML/markdown, etc.)
    def formatted_text
      return nil unless valid?
      
      text # Currently returns plain text, but could add formatting in the future
    end
    
    # Get all content parts
    def parts
      return [] unless valid?
      
      first_candidate&.dig("content", "parts") || []
    end
    
    # Get all text parts as an array
    def text_parts
      return [] unless valid?
      
      parts.select { |part| part.key?("text") }.map { |part| part["text"] }
    end
    
    # Get image parts (if any)
    def image_parts
      return [] unless valid?
      
      parts.select { |part| part.key?("inline_data") && part["inline_data"]["mime_type"].start_with?("image/") }
    end
    
    # Get all content with string representation
    def full_content
      parts.map do |part|
        if part.key?("text")
          part["text"]
        elsif part.key?("inline_data") && part["inline_data"]["mime_type"].start_with?("image/")
          "[IMAGE: #{part["inline_data"]["mime_type"]}]"
        else
          "[UNKNOWN CONTENT]"
        end
      end.join("\n")
    end
    
    # Get the first candidate
    def first_candidate
      @raw_data&.dig("candidates", 0)
    end
    
    # Get all candidates (if multiple candidates are present)
    def candidates
      @raw_data&.dig("candidates") || []
    end
    
    # Check if response is valid
    def valid?
      !@raw_data.nil? && 
      ((@raw_data.key?("candidates") && !@raw_data["candidates"].empty?) || 
       (@raw_data.key?("predictions") && !@raw_data["predictions"].empty?))
    end
    
    # Get error message if any
    def error
      return nil if valid?
      
      # Return nil for empty responses (to display "Empty response" in to_s method)
      return nil if @raw_data.nil? || @raw_data.empty?
      
      @raw_data&.dig("error", "message") || "Unknown error"
    end
    
    # Check if response was successful
    def success?
      valid? && !@raw_data.key?("error")
    end
    
    # Get finish reason (STOP, SAFETY, etc.)
    def finish_reason
      first_candidate&.dig("finishReason")
    end
    
    # Check if response was blocked for safety reasons
    def safety_blocked?
      finish_reason == "SAFETY"
    end
    
    # Get token usage information
    def usage
      @raw_data&.dig("usage") || {}
    end
    
    # Get number of prompt tokens used
    def prompt_tokens
      usage&.dig("promptTokens") || 0
    end
    
    # Get number of tokens used for completion
    def completion_tokens
      usage&.dig("candidateTokens") || 0
    end
    
    # Get total tokens used
    def total_tokens
      usage&.dig("totalTokens") || 0
    end
    
    # Process chunks for streaming responses
    def stream_chunks
      return [] unless @raw_data.is_a?(Array)
      
      @raw_data
    end
    
    # Get image URLs from multimodal responses (if any)
    def image_urls
      return [] unless valid?
      
      first_candidate&.dig("content", "parts")
        &.select { |part| part.key?("image_url") }
        &.map { |part| part.dig("image_url", "url") } || []
    end
    
    # Get function call information
    def function_calls
      return [] unless valid?
      
      first_candidate&.dig("content", "parts")
        &.select { |part| part.key?("functionCall") }
        &.map { |part| part["functionCall"] } || []
    end
    
    # Get response role (usually "model")
    def role
      first_candidate&.dig("content", "role")
    end
    
    # Get safety ratings
    def safety_ratings
      first_candidate&.dig("safetyRatings") || []
    end
    
    # 画像生成結果から最初の画像を取得（Base64エンコード形式）
    def image
      images.first
    end
    
    # 画像生成結果からすべての画像を取得（Base64エンコード形式の配列）
    def images
      image_array = []
      return image_array unless @raw_data
      
      # Gemini 2.0スタイルレスポンスを正確に解析
      # キーはcamelCase形式で使用されているので注意（inlineDataなど）
      if @raw_data.key?('candidates') && !@raw_data['candidates'].empty?
        candidate = @raw_data['candidates'][0]
        if candidate.key?('content') && candidate['content'].key?('parts')
          parts = candidate['content']['parts']
          
          parts.each do |part|
            # キャメルケースでアクセス（inlineData）
            if part.key?('inlineData')
              inline_data = part['inlineData']
              if inline_data.key?('mimeType') && 
                 inline_data['mimeType'].to_s.start_with?('image/') &&
                 inline_data.key?('data')
                
                # 画像データを追加
                image_array << inline_data['data']
                puts "画像データを検出しました: #{inline_data['mimeType']}" if ENV["DEBUG"]
              end
            end
          end
        end
      # Imagen 3スタイルレスポンスのチェック
      elsif @raw_data.key?('predictions')
        @raw_data['predictions'].each do |pred|
          if pred.key?('bytesBase64Encoded')
            image_array << pred['bytesBase64Encoded']
            puts "Imagen 3形式の画像データを検出しました" if ENV["DEBUG"]
          end
        end
      end
      
      # フォールバック：直接JSONから抽出
      if image_array.empty?
        puts "標準的な方法で画像データが見つかりませんでした。正規表現による抽出を試みます..." if ENV["DEBUG"]
        raw_json = @raw_data.to_json
        
        # "data"キーで長いBase64文字列を検索
        base64_matches = raw_json.scan(/"data":"([A-Za-z0-9+\/=]{100,})"/)
        if !base64_matches.empty?
          puts "検出したBase64データ: #{base64_matches.size}個" if ENV["DEBUG"]
          base64_matches.each do |match|
            image_array << match[0]
          end
        end
      end
      
      puts "検出した画像データ数: #{image_array.size}" if ENV["DEBUG"]
      image_array
    end
    
    # 画像のMIMEタイプを取得
    def image_mime_types
      return [] unless valid?
      
      if first_candidate&.dig("content", "parts")
        first_candidate["content"]["parts"]
          .select { |part| part.key?("inline_data") && part["inline_data"]["mime_type"].start_with?("image/") }
          .map { |part| part["inline_data"]["mime_type"] }
      else
        # Imagen 3のデフォルトはPNG
        Array.new(images.size, "image/png")
      end
    end
    
    # 最初の画像をファイルに保存
    def save_image(filepath)
      save_images([filepath]).first
    end
    
    # 複数の画像をファイルに保存
    def save_images(filepaths)
      require 'base64'
      
      result = []
      image_data = images
      
      puts "保存する画像データ数: #{image_data.size}" if ENV["DEBUG"]
      
      # ファイルパスと画像データの数が一致しない場合
      if filepaths.size < image_data.size
        puts "警告: ファイルパスの数(#{filepaths.size})が画像データの数(#{image_data.size})より少ないです" if ENV["DEBUG"]
        # ファイルパスの数に合わせて画像データを切り詰める
        image_data = image_data[0...filepaths.size]
      elsif filepaths.size > image_data.size
        puts "警告: ファイルパスの数(#{filepaths.size})が画像データの数(#{image_data.size})より多いです" if ENV["DEBUG"]
        # 画像データの数に合わせてファイルパスを切り詰める
        filepaths = filepaths[0...image_data.size]
      end
      
      image_data.each_with_index do |data, i|
        begin
          if !data || data.empty?
            puts "警告: インデックス #{i} の画像データが空です" if ENV["DEBUG"]
            result << nil
            next
          end
          
          # データがBase64エンコードされていることを確認
          if data.match?(/^[A-Za-z0-9+\/=]+$/)
            # 一般的なBase64データ
            decoded_data = Base64.strict_decode64(data)
          else
            # データプレフィックスがある場合など（例: data:image/png;base64,xxxxx）
            if data.include?('base64,')
              base64_part = data.split('base64,').last
              decoded_data = Base64.strict_decode64(base64_part)
            else
              puts "警告: インデックス #{i} のデータはBase64形式ではありません" if ENV["DEBUG"]
              decoded_data = data # 既にバイナリかもしれない
            end
          end
          
          File.open(filepaths[i], 'wb') do |f|
            f.write(decoded_data)
          end
          result << filepaths[i]
        rescue => e
          puts "エラー: 画像 #{i} の保存中にエラーが発生しました: #{e.message}" if ENV["DEBUG"]
          puts e.backtrace.join("\n") if ENV["DEBUG"]
          result << nil
        end
      end
      
      result
    end
    
    # Override to_s method to return text
    def to_s
      text || error || "Empty response"
    end
    
    # Inspection method for debugging
    def inspect
      "#<Gemini::Response text=#{text ? text[0..30] + (text.length > 30 ? '...' : '') : 'nil'} success=#{success?}>"
    end
  end
end