require 'bundler/setup'
require 'gemini'  # geminiライブラリを読み込む
require 'logger'

# ロガーの設定
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# APIキーを環境変数から取得
api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY環境変数を設定してください")

begin
  # クライアントの初期化
  logger.info "Geminiクライアントを初期化しています..."
  client = Gemini::Client.new(api_key)
  
  puts "音声ファイルの文字起こしを開始します"
  puts "==================================="
  
  # 音声ファイルのパスを指定
  audio_file_path = ARGV[0] || raise("使用方法: ruby audio_demo.rb <音声ファイルのパス>")
  
  # ファイルの存在確認
  unless File.exist?(audio_file_path)
    raise "ファイルが見つかりません: #{audio_file_path}"
  end
  
  # ファイル情報を表示
  file_size = File.size(audio_file_path) / 1024.0 # KB単位
  file_extension = File.extname(audio_file_path)
  puts "ファイル: #{File.basename(audio_file_path)}"
  puts "サイズ: #{file_size.round(2)} KB"
  puts "タイプ: #{file_extension}"
  puts "==================================="
  
  # 処理開始時間
  start_time = Time.now
  
  # 文字起こし実行
  logger.info "音声ファイルをアップロードして文字起こしを実行しています..."
  puts "処理中..."
  
  # ファイルを開く
  file = File.open(audio_file_path, "rb")
  
  begin
    response = client.audio.transcribe(
      parameters: {
        model: "gemini-1.5-flash", # Geminiのモデルを指定
        file: file,
        language: "ja", # 言語を指定（必要に応じて変更してください）
        content_text: "この音声を文字起こししてください。"
      }
    )
  ensure
    # 必ずファイルを閉じる
    file.close
  end
  
  # 処理終了時間と経過時間の計算
  end_time = Time.now
  elapsed_time = end_time - start_time
  
  # 結果表示
  puts "\n=== 文字起こし結果 ==="
  puts response["text"]
  puts "======================="
  puts "処理時間: #{elapsed_time.round(2)} 秒"
  
  # 生のレスポンスも確認したい場合
  # puts "\n=== 生のレスポンス ==="
  # puts JSON.pretty_generate(response["raw_response"])
  
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