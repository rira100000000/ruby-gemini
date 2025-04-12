module Gemini
  class Images
    def initialize(client:)
      @client = client
    end

    # 画像を生成するメインメソッド
    def generate(parameters: {})
      prompt = parameters[:prompt]
      raise ArgumentError, "prompt parameter is required" unless prompt

      # モデルの決定（デフォルトはGemini 2.0）
      model = parameters[:model] || "gemini-2.0-flash-exp-image-generation"
      
      # モデルに応じた画像生成処理
      if model.start_with?("imagen")
        # Imagen 3を使用
        response = imagen_generate(prompt, parameters)
      else
        # Gemini 2.0を使用
        response = gemini_generate(prompt, parameters)
      end
      
      # レスポンスをラップして返す
      Gemini::Response.new(response)
    end
    
    private
    
    # Gemini 2.0モデルを使用した画像生成
    def gemini_generate(prompt, parameters)
      # パラメータの準備
      model = parameters[:model] || "gemini-2.0-flash-exp-image-generation"
      
      # サイズパラメータの処理（現在はGemini APIでは使用しない）
      # aspect_ratio = process_size_parameter(parameters[:size])
      
      # 生成設定の構築
      generation_config = {
        "responseModalities" => ["Text", "Image"]
      }
      
      # リクエストパラメータの構築
      request_params = {
        "contents" => [{
          "parts" => [
            {"text" => prompt}
          ]
        }],
        "generationConfig" => generation_config
      }
      
      # API呼び出し
      @client.json_post(
        path: "models/#{model}:generateContent",
        parameters: request_params
      )
    end
    
    # Imagen 3モデルを使用した画像生成
    def imagen_generate(prompt, parameters)
      # モデル名の取得（デフォルトはImagen 3の標準モデル）
      model = parameters[:model] || "imagen-3.0-generate-002"
      
      # サイズパラメータからアスペクト比を取得
      aspect_ratio = process_size_parameter(parameters[:size])
      
      # 画像生成数の設定
      sample_count = parameters[:n] || parameters[:sample_count] || 1
      sample_count = [[sample_count.to_i, 1].max, 4].min # 1〜4の範囲に制限
      
      # 人物生成の設定
      person_generation = parameters[:person_generation] || "ALLOW_ADULT"
      
      # リクエストパラメータの構築
      request_params = {
        "instances" => [
          {
            "prompt" => prompt
          }
        ],
        "parameters" => {
          "sampleCount" => sample_count
        }
      }
      
      # アスペクト比が指定されている場合は追加
      request_params["parameters"]["aspectRatio"] = aspect_ratio if aspect_ratio
      
      # 人物生成設定を追加
      request_params["parameters"]["personGeneration"] = person_generation
      
      # API呼び出し
      @client.json_post(
        path: "models/#{model}:predict",
        parameters: request_params
      )
    end
    
    # サイズパラメータからアスペクト比を決定
    def process_size_parameter(size)
      return nil unless size
      
      case size.to_s
      when "256x256", "512x512", "1024x1024"
        "1:1"
      when "256x384", "512x768", "1024x1536"
        "3:4"
      when "384x256", "768x512", "1536x1024"
        "4:3"
      when "256x448", "512x896", "1024x1792"
        "9:16"
      when "448x256", "896x512", "1792x1024"
        "16:9"
      when "1:1", "3:4", "4:3", "9:16", "16:9"
        size.to_s
      else
        "1:1" # デフォルト
      end
    end
  end
end