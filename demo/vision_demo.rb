# 画像URLを使用して質問する例
require 'gemini'

client = Gemini::Client.new

# To load an image from a local file
response = client.generate_content(
  [
    { 
      type: "text", 
      text: " describe what you see in this image"
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