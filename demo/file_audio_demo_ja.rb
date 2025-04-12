require 'bundler/setup'
require 'gemini'
require 'logger'

# デバッグモードを有効化
ENV["DEBUG"] = "true"

# ロガーの設定
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# APIキーを環境変数から取得
api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY環境変数を設定してください")

begin
  # クライアントの初期化
  logger.info "Geminiクライアントを初期化しています..."
  client = Gemini::Client.new(api_key)
  
  puts "File APIを使用した音声ファイルの文字起こしデモ（Response対応版）"
  puts "==============================================="
  
  # 音声ファイルのパスを指定
  audio_file_path = ARGV[0] || raise("使用方法: ruby file_audio_demo_ja.rb <音声ファイルのパス>")
  
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
  puts "==============================================="
  
  # 処理開始時間
  start_time = Time.now
  
  # ファイルをアップロード
  logger.info "音声ファイルをアップロードしています..."
  puts "アップロード中..."
  
  # クライアント情報の確認
  puts "クライアント情報:"
  puts "URI Base: #{client.uri_base}"
  
  file = File.open(audio_file_path, "rb")
  begin
    # アップロード処理
    puts "ファイルアップロード処理を開始します..."
    upload_result = client.files.upload(file: file)
    
    # 成功した場合の処理
    file_uri = upload_result["file"]["uri"]
    file_name = upload_result["file"]["name"]
    
    puts "ファイルをアップロードしました："
    puts "File URI: #{file_uri}"
    puts "File Name: #{file_name}"
    
    # 文字起こし実行
    logger.info "アップロードしたファイルの文字起こしを実行しています..."
    puts "文字起こし中..."
    
    # リトライロジックを追加（503エラー対策）
    max_retries = 3
    retry_count = 0
    retry_delay = 2 # 開始遅延（秒）
    
    begin
      # 修正した audio.rb を使う
      response = client.audio.transcribe(
        parameters: {
          file_uri: file_uri,
          language: "ja", # 言語を指定（必要に応じて変更してください）
          content_text: "この音声を文字起こししてください。"
        }
      )
      
      # Responseオブジェクトをデバッグログに出力
      if ENV["DEBUG"] == "true"
        logger.debug "レスポンスタイプ: #{response.class}"
        logger.debug "raw_dataタイプ: #{response.raw_data.class}" if response.respond_to?(:raw_data)
      end
      
    rescue Faraday::ServerError => e
      retry_count += 1
      if retry_count <= max_retries
        puts "サーバーエラーが発生しました。#{retry_delay}秒後に再試行します... (#{retry_count}/#{max_retries})"
        sleep retry_delay
        # 指数バックオフ（遅延を2倍に）
        retry_delay *= 2
        retry
      else
        raise e
      end
    end
    
    # 処理終了時間と経過時間の計算
    end_time = Time.now
    elapsed_time = end_time - start_time
    
    # 結果表示 - Responseオブジェクトのメソッドを使用
    puts "\n=== 文字起こし結果 ==="
    
    # レスポンスが Gemini::Response かつ valid? メソッドを持つことを確認
    if response.is_a?(Gemini::Response) && response.respond_to?(:valid?)
      if response.valid?
        puts response.text
      else
        puts "レスポンスの取得に失敗しました: #{response.error || '不明なエラー'}"
      end
    elsif response.respond_to?(:dig) && response.dig("candidates", 0, "content", "parts", 0, "text")
      # ハッシュの場合はそのまま表示（fallback）
      puts response.dig("candidates", 0, "content", "parts", 0, "text")
    else
      # それ以外の場合は直接文字列に変換
      puts response.to_s
    end
    
    puts "======================="
    puts "処理時間: #{elapsed_time.round(2)} 秒"
    
    # 詳細情報（デバッグ用）
    if ENV["DEBUG"] == "true" && response.is_a?(Gemini::Response) && response.respond_to?(:valid?) && response.valid?
      puts "\n=== レスポンス詳細情報 ==="
      puts "成功: #{response.success?}"
      puts "終了理由: #{response.finish_reason}" if response.finish_reason
      puts "テキスト部分の数: #{response.text_parts.size}"
      puts "トークン使用量: #{response.total_tokens}" if response.total_tokens > 0
      puts "======================="
    end
    
    # アップロードしたファイルの情報表示
    begin
      file_info = client.files.get(name: file_name)
      puts "\n=== ファイル情報 ==="
      puts "Name: #{file_info['name']}"
      puts "Display Name: #{file_info['displayName']}" if file_info['displayName']
      puts "MIME Type: #{file_info['mimeType']}" if file_info['mimeType']
      puts "Size: #{file_info['sizeBytes'].to_i / 1024.0} KB" if file_info['sizeBytes']
      puts "作成日時: #{Time.at(file_info['createTime'].to_i).strftime('%Y-%m-%d %H:%M:%S')}" if file_info['createTime']
      puts "有効期限: #{Time.at(file_info['expirationTime'].to_i).strftime('%Y-%m-%d %H:%M:%S')}" if file_info['expirationTime']
      puts "URI: #{file_info['uri']}" if file_info['uri']
      puts "Status: #{file_info['state']}" if file_info['state']
      puts "======================="
    rescue => e
      puts "ファイル情報の取得に失敗しました: #{e.message}"
    end
    
    puts "ファイルは48時間後に自動的に削除されます"
  rescue => e
    puts "ファイルアップロード中にエラーが発生しました: #{e.class} - #{e.message}"
    puts e.backtrace.join("\n") if ENV["DEBUG"]
  ensure
    file.close
  end
  
rescue StandardError => e
  logger.error "エラーが発生しました: #{e.message}"
  logger.error e.backtrace.join("\n") if ENV["DEBUG"]
  
  puts "\n詳細エラー情報:"
  puts "#{e.class}: #{e.message}"
  
  # APIエラーの詳細情報
  if defined?(Faraday::Error) && e.is_a?(Faraday::Error)
    puts "API接続エラー: #{e.message}"
    if e.response
      puts "レスポンスステータス: #{e.response[:status]}"
      puts "レスポンスボディ: #{e.response[:body]}"
    end
  end
end