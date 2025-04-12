require 'bundler/setup'
require 'gemini'
require 'json'
require 'pp'

api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY環境変数を設定してください")

begin
  puts "Geminiクライアントを初期化しています..."
  client = Gemini::Client.new(api_key)
  
  puts "Gemini 構造化出力デモ"
  puts "==================================="

  # スキーマを直接指定してJSONレスポンスを要求する  
  # レシピのスキーマを定義
  recipe_schema = {
    type: "ARRAY",
    items: {
      type: "OBJECT",
      properties: {
        "recipe_name": { type: "STRING" },
        "ingredients": {
          type: "ARRAY",
          items: { type: "STRING" }
        },
        "preparation_time": {
          type: "INTEGER",
          description: "調理時間（分）"
        }
      },
      required: ["recipe_name", "ingredients"],
      propertyOrdering: ["recipe_name", "ingredients", "preparation_time"]
    }
  }
  
  response = client.generate_content(
    "人気のクッキーレシピを3つ紹介してください。各レシピには名前、材料、調理時間を含めてください。",
    response_mime_type: "application/json",
    response_schema: recipe_schema
  )
  
  if response.success? && response.json?
    puts "JSONレスポンス:"
    pp response.json
    
    # レスポンスの構造を活用した例
    puts "\n調理時間の短い順にレシピをソート:"
    sorted_recipes = response.json.sort_by { |recipe| recipe["preparation_time"] || Float::INFINITY }
    sorted_recipes.each do |recipe|
      prep_time = recipe["preparation_time"] ? "#{recipe["preparation_time"]}分" : "時間不明"
      puts "#{recipe["recipe_name"]} (#{prep_time})"
      puts "  材料: #{recipe["ingredients"].join(", ")}" if recipe["ingredients"]
      puts
    end
  else
    puts "JSONの取得に失敗しました: #{response.error || '不明なエラー'}"
    puts "テキストレスポンス:"
    puts response.text
  end
  
  puts "\n==================================="
  puts "デモ完了"

rescue StandardError => e
  puts "\nエラーが発生しました: #{e.message}"
  puts e.backtrace.join("\n") if ENV["DEBUG"]
end