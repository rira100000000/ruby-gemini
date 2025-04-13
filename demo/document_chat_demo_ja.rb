require 'bundler/setup'
require 'gemini'
require 'logger'

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# APIキーを環境変数から取得
api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY環境変数を設定してください")

begin
  logger.info "Geminiクライアントを初期化しています..."
  client = Gemini::Client.new(api_key)
  
  puts "Gemini ドキュメントチャットデモ"
  puts "==================================="
  
  # ドキュメントファイルのパスを指定
  document_path = ARGV[0] || raise("使用方法: ruby document_chat_demo.rb <ドキュメントファイルのパス> [プロンプト]")
  
  # プロンプトを指定
  prompt = ARGV[1] || "このドキュメントの要約を3点にまとめてください"
  
  # ファイルの存在確認
  unless File.exist?(document_path)
    raise "ファイルが見つかりません: #{document_path}"
  end
  
  # ファイル情報を表示
  file_size = File.size(document_path) / 1024.0 # KB単位
  file_extension = File.extname(document_path)
  puts "ファイル: #{File.basename(document_path)}"
  puts "サイズ: #{file_size.round(2)} KB"
  puts "タイプ: #{file_extension}"
  puts "プロンプト: #{prompt}"
  puts "==================================="
  
  # 処理開始時間
  start_time = Time.now
  
  # 処理方法を選択（デフォルトはドキュメント処理クラスを使用）
  use_direct_approach = ENV['USE_DIRECT'] == 'true'
  
  puts "処理方法: #{use_direct_approach ? '直接APIを使用' : 'Documentsクラスを使用'}"
  puts "ドキュメントを処理中..."
  
  if use_direct_approach
    # 直接APIを使用する方法
    result = client.upload_and_process_file(document_path, prompt)
    response = result[:response]
  else
    # Documentsクラスを使用する方法
    result = client.documents.process(file_path: document_path, prompt: prompt)
    response = result[:response]
  end
  
  # 処理終了時間と経過時間の計算
  end_time = Time.now
  elapsed_time = end_time - start_time
  
  puts "\n=== ドキュメント処理結果 ==="
  
  if response.success?
    puts response.text
  else
    puts "エラー: #{response.error || '不明なエラー'}"
  end
  
  puts "======================="
  puts "処理時間: #{elapsed_time.round(2)} 秒"
  
  # ファイル情報
  puts "ファイルURI: #{result[:file_uri]}"
  puts "ファイル名: #{result[:file_name]}"
  
  # トークン使用量情報（利用可能な場合）
  if response.total_tokens > 0
    puts "\nトークン使用量:"
    puts "  プロンプト: #{response.prompt_tokens}"
    puts "  生成: #{response.completion_tokens}"
    puts "  合計: #{response.total_tokens}"
  end

rescue StandardError => e
  logger.error "エラーが発生しました: #{e.message}"
  logger.error e.backtrace.join("\n") if ENV["DEBUG"]
end