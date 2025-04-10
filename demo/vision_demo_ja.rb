# 画像URLを使用して質問する例
require 'gemini'

client = Gemini::Client.new

# ローカルファイルから画像を読み込む場合
response = client.generate_content(
  [
    { 
      type: "text", 
      text: "この画像に写っているものを説明してください"
    },
    { 
      type: "image_file", 
      image_file: { 
        file_path: "demo/pui_mol.png" 
      } 
    }
  ],
  model: "gemini-2.0-flash"
)

puts response.dig("candidates", 0, "content", "parts", 0, "text")