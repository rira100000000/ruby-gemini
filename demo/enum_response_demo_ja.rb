require 'bundler/setup'
require 'gemini'
require 'json'
require 'pp'

# APIキーを環境変数から読み込む
api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY環境変数を設定してください")

begin
  puts "Geminiクライアントを初期化しています..."
  client = Gemini::Client.new(api_key)
  
  puts "Gemini enum制約付き応答デモ"
  puts "==================================="

  # 例1: シンプルなenum制約（天気予報）
  puts "\n例1: 天気予報（シンプルなenum）"
  puts "---------------------------------"
  
  # 天気予報のスキーマを定義（enumを使って応答を制約）
  weather_schema = {
    type: "OBJECT",
    properties: {
      "forecast": {
        type: "STRING",
        # enumで許可される値のみを指定
        enum: ["晴れ", "曇り", "雨", "雪", "霧"]
      },
      "temperature": {
        type: "INTEGER",
        description: "気温（摂氏）"
      }
    },
    required: ["forecast", "temperature"]
  }
  
  response = client.generate_content(
    "明日の東京の天気予報をシンプルに教えてください。",
    response_mime_type: "application/json",
    response_schema: weather_schema
  )
  
  if response.success? && response.json?
    puts "JSONレスポンス:"
    pp response.json
    
    # レスポンスを使った表示例
    forecast = response.json["forecast"]
    temp = response.json["temperature"]
    puts "\n明日の東京の天気は「#{forecast}」で、気温は#{temp}℃の予想です。"
  else
    puts "JSONの取得に失敗しました: #{response.error || '不明なエラー'}"
    puts "テキストレスポンス: #{response.text}"
  end
  
  # 例2: 商品レビュー（修正版）
  puts "\n\n例2: 商品レビュー（修正版）"
  puts "---------------------------------"
  
  # 商品レビューのスキーマを修正
  review_schema = {
    type: "OBJECT",
    properties: {
      "product_name": { 
        type: "STRING" 
      },
      # 評価は1～5のみ許可（文字列として扱う）
      "rating": {
        type: "STRING",
        enum: ["1", "2", "3", "4", "5"],
        description: "1から5の評価（5が最高）"
      },
      # おすすめ度も列挙された値から選択
      "recommendation": {
        type: "STRING",
        enum: ["おすすめしない", "どちらでもない", "おすすめする", "強くおすすめする"],
        description: "商品のおすすめ度"
      },
      "comment": { 
        type: "STRING" 
      }
    },
    required: ["product_name", "rating", "recommendation"]
  }
  
  response = client.generate_content(
    "新型スマートフォン「GeminiPhone 15」のレビューを簡潔に作成してください。",
    response_mime_type: "application/json",
    response_schema: review_schema
  )
  
  if response.success? && response.json?
    puts "JSONレスポンス:"
    pp response.json
    
    # レスポンスを使った表示例
    review = response.json
    puts "\n商品レビュー: #{review['product_name']}"
    puts "評価: #{review['rating']}/5 (#{review['recommendation']})"
    puts "コメント: #{review['comment']}" if review['comment']
  else
    puts "JSONの取得に失敗しました: #{response.error || '不明なエラー'}"
    puts "テキストレスポンス: #{response.text}"
  end

  puts "\n==================================="
  puts "デモ完了"

rescue StandardError => e
  puts "\nエラーが発生しました: #{e.message}"
  puts e.backtrace.join("\n") if ENV["DEBUG"]
end