require 'bundler/setup'
require 'gemini'
require 'logger'
require 'readline'

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# APIキーを環境変数から取得
api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY環境変数を設定してください")

begin
  logger.info "Geminiクライアントを初期化しています..."
  client = Gemini::Client.new(api_key)
  
  puts "Gemini ドキュメントキャッシュデモ"
  puts "==================================="
  
  # ドキュメントファイルのパスを指定
  document_path = ARGV[0] || raise("使用方法: ruby document_cache_demo.rb <ドキュメントファイルのパス>")
  
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
  puts "==================================="
  
  # 処理開始時間
  start_time = Time.now
  
  # システム指示を設定
  system_instruction = "あなたはドキュメント分析の専門家です。与えられたドキュメントの内容を正確に把握し、質問に詳細に答えてください。"
  
  puts "ドキュメントをキャッシュに保存中..."
  
  # 処理方法を選択（デフォルトはドキュメント処理クラスを使用）
  use_direct_approach = ENV['USE_DIRECT'] == 'true'
  
  if use_direct_approach
    # 直接APIを使用する方法
    file = File.open(document_path, "rb")
    begin
      upload_result = client.files.upload(file: file)
      file_uri = upload_result["file"]["uri"]
      mime_type = client.determine_mime_type(document_path)
      
      # キャッシュに保存
      cache_result = client.cached_content.create(
        file_uri: file_uri,
        mime_type: mime_type,
        system_instruction: system_instruction,
        ttl: "3600s"  # 1時間の有効期限
      )
    ensure
      file.close
    end
  else
    # Documentsクラスを使用する方法
    result = client.documents.cache(
      file_path: document_path,
      system_instruction: system_instruction,
      ttl: "3600s"  # 1時間の有効期限
    )
    cache_result = result[:cache]
    file_uri = result[:file_uri]
  end
  
  # キャッシュ名を取得
  if cache_result.success? && cache_result.raw_data["name"]
    cache_name = cache_result.raw_data["name"]
    
    # 処理終了時間と経過時間の計算
    end_time = Time.now
    elapsed_time = end_time - start_time
    
    puts "ドキュメントがキャッシュに保存されました！"
    puts "キャッシュ名: #{cache_name}"
    puts "処理時間: #{elapsed_time.round(2)} 秒"
    puts "==================================="
    
    # コマンド補完用の設定
    COMMANDS = ['exit', 'list', 'delete', 'help'].freeze
    Readline.completion_proc = proc { |input|
      COMMANDS.grep(/^#{Regexp.escape(input)}/)
    }
    
    puts "\nキャッシュされたドキュメントに質問できます。コマンド: exit (終了), list (一覧), delete (削除), help (ヘルプ)"
    
    # 会話ループ
    loop do
      # ユーザー入力
      user_input = Readline.readline("\n> ", true)
      
      # 入力がnil（Ctrl+D）の場合
      break if user_input.nil?
      
      user_input = user_input.strip
      
      # コマンド処理
      case user_input.downcase
      when 'exit'
        puts "デモを終了します。"
        break
        
      when 'list'
        puts "\n=== キャッシュ一覧 ==="
        list_response = client.cached_content.list
        
        if list_response.success? && list_response.raw_data["cachedContents"]
          cached_contents = list_response.raw_data["cachedContents"]
          if cached_contents.empty?
            puts "キャッシュが見つかりません。"
          else
            cached_contents.each do |cache|
              puts "名前: #{cache['name']}"
              puts "モデル: #{cache['model']}"
              puts "作成時間: #{Time.at(cache['createTime'].to_i).strftime('%Y-%m-%d %H:%M:%S')}" if cache['createTime']
              puts "有効期限: #{Time.at(cache['expireTime'].to_i).strftime('%Y-%m-%d %H:%M:%S')}" if cache['expireTime']
              puts "--------------------------"
            end
          end
        else
          puts "キャッシュの取得に失敗しました: #{list_response.error || '不明なエラー'}"
        end
        next
        
      when 'delete'
        puts "\nキャッシュを削除します: #{cache_name}"
        delete_response = client.cached_content.delete(name: cache_name)
        
        if delete_response.success?
          puts "キャッシュが削除されました。"
          puts "デモを終了します。"
          break
        else
          puts "キャッシュの削除に失敗しました: #{delete_response.error || '不明なエラー'}"
        end
        next
        
      when 'help'
        puts "\nコマンド:"
        puts "  exit   - デモを終了"
        puts "  list   - キャッシュ一覧を表示"
        puts "  delete - 現在のキャッシュを削除"
        puts "  help   - このヘルプを表示"
        puts "  その他 - ドキュメントに関する質問"
        next
        
      when ''
        # 空の入力の場合はスキップ
        next
      end
      
      # 質問処理
      begin
        query_start_time = Time.now
        
        # キャッシュを使って質問
        response = client.generate_content(
          user_input,
          parameters: { cachedContent: cache_name }
        )
        
        query_end_time = Time.now
        query_time = query_end_time - query_start_time
        
        if response.success?
          puts "\n回答:"
          puts response.text
          puts "\n処理時間: #{query_time.round(2)} 秒"
          
          # トークン使用量情報（利用可能な場合）
          if response.total_tokens > 0
            puts "トークン使用量:"
            puts "  プロンプト: #{response.prompt_tokens}"
            puts "  生成: #{response.completion_tokens}"
            puts "  合計: #{response.total_tokens}"
          end
        else
          puts "エラー: #{response.error || '不明なエラー'}"
        end
      rescue => e
        puts "質問の処理中にエラーが発生しました: #{e.message}"
      end
    end
  else
    puts "キャッシュの作成に失敗しました: #{cache_result.error || '不明なエラー'}"
  end

rescue StandardError => e
  logger.error "エラーが発生しました: #{e.message}"
  logger.error e.backtrace.join("\n") if ENV["DEBUG"]
end