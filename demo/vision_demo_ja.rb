# 画像URLを使用して質問する例
require 'bundler/setup'
require 'gemini'
require 'logger'

# ロガーの設定
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# APIキーを環境変数から取得、または直接指定
api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY環境変数を設定してください")

begin
  # クライアントの初期化
  logger.info "Geminiクライアントを初期化しています..."
  client = Gemini::Client.new(api_key)

  puts "Gemini Vision APIデモ"
  puts "==================================="
  
  # 画像ファイルのパスを指定
  image_file_path = ARGV[0] || raise("使用方法: ruby vision_demo_ja.rb <画像ファイルのパス>")
  
  # ファイルの存在確認
  unless File.exist?(image_file_path)
    raise "ファイルが見つかりません: #{image_file_path}"
  end
  
  # ファイル情報を表示
  file_size = File.size(image_file_path) / 1024.0 # KB単位
  file_extension = File.extname(image_file_path)
  puts "ファイル: #{File.basename(image_file_path)}"
  puts "サイズ: #{file_size.round(2)} KB"
  puts "タイプ: #{file_extension}"
  puts "==================================="
  
  # 処理開始時間
  start_time = Time.now

  # ローカルファイルから画像を読み込む
  response = client.generate_content(
    [
      { 
        type: "text", 
        text: "この画像に写っているものを説明してください"
      },
      { 
        type: "image_file", 
        image_file: { 
          file_path: image_file_path
        } 
      }
    ],
    model: "gemini-2.0-flash"
  )

  # 処理終了時間と経過時間の計算
  end_time = Time.now
  elapsed_time = end_time - start_time

  # Responseクラスのメソッドを使用して結果を表示
  puts "\n=== 画像分析結果 ==="
  if response.success?
    puts response.text
    
    # 解析にあたって使用されたトークン数の表示（利用可能な場合）
    if response.usage && !response.usage.empty?
      puts "\nトークン使用量:"
      puts "プロンプトトークン: #{response.prompt_tokens}"
      puts "生成トークン: #{response.completion_tokens}"
      puts "合計トークン: #{response.total_tokens}"
    end
    
    # 安全性フィルターの結果表示（存在する場合）
    if !response.safety_ratings.empty?
      puts "\n安全性評価:"
      response.safety_ratings.each do |rating|
        puts "カテゴリ: #{rating['category']}, レベル: #{rating['probability']}"
      end
    end
  else
    puts "エラーが発生しました: #{response.error || '不明なエラー'}"
  end
  
  puts "==================================="
  puts "処理時間: #{elapsed_time.round(2)} 秒"

rescue StandardError => e
  logger.error "エラーが発生しました: #{e.message}"
  logger.error e.backtrace.join("\n") if ENV["DEBUG"]
  
  puts "\n詳細エラー情報:"
  puts "#{e.class}: #{e.message}"
  
  # APIエラーの詳細情報
  if defined?(Faraday::Error) && e.is_a?(Faraday::Error)
    puts "API接続エラー: #{e.message}"
  end
end