require 'bundler/setup'
require 'gemini'
require 'logger'
require 'readline'
require 'securerandom'

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# APIキーを環境変数から取得
api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY環境変数を設定してください")

begin
  logger.info "Geminiクライアントを初期化しています..."
  client = Gemini::Client.new(api_key)
  
  puts "Gemini ドキュメント会話デモ"
  puts "==================================="
  
  # ドキュメントファイルのパスを指定
  document_path = ARGV[0] || raise("使用方法: ruby document_chat_conversation_demo.rb <ドキュメントファイルのパス>")
  
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
  
  puts "ドキュメントを処理中..."
  model = "gemini-1.5-flash"
  
  # ファイルをアップロード
  file = File.open(document_path, "rb")
  begin
    upload_result = client.files.upload(file: file)
    file_uri = upload_result["file"]["uri"]
    file_name = upload_result["file"]["name"]
    
    # MIMEタイプを判定（拡張子から簡易判定）
    mime_type = case file_extension.downcase
                when ".pdf"
                  "application/pdf"
                when ".txt"
                  "text/plain"
                when ".html", ".htm"
                  "text/html"
                when ".css"
                  "text/css"
                when ".md"
                  "text/md"
                when ".csv"
                  "text/csv"
                when ".xml"
                  "text/xml"
                when ".rtf"
                  "text/rtf"
                when ".js"
                  "application/x-javascript"
                when ".py"
                  "application/x-python"
                else
                  "application/octet-stream"
                end
  ensure
    file.close
  end
  
  puts "ファイルがアップロードされました: #{file_name}"
  
  # 会話履歴
  conversation_history = []
  
  # 最初のメッセージを追加（ドキュメント）
  conversation_history << {
    role: "user",
    parts: [
      { file_data: { mime_type: mime_type, file_uri: file_uri } }
    ]
  }
  
  # 最初の質問を追加
  first_question = "このドキュメントについて簡単に説明してください。"
  conversation_history << {
    role: "user",
    parts: [{ text: first_question }]
  }
  
  puts "最初の質問: #{first_question}"
  
  # Gemini APIに送信
  response = client.chat(parameters: {
    model: model,
    contents: conversation_history
  })
  
  if response.success?
    # 応答をログに追加
    conversation_history << {
      role: "model",
      parts: [{ text: response.text }]
    }
    
    # 応答を表示
    puts "\n[モデル]: #{response.text}"
  else
    raise "最初の応答を生成できませんでした: #{response.error || '不明なエラー'}"
  end
  
  # コマンド補完用の設定
  COMMANDS = ['exit', 'history', 'help'].freeze
  Readline.completion_proc = proc { |input|
    COMMANDS.grep(/^#{Regexp.escape(input)}/)
  }
  
  puts "\nドキュメントについて質問できます。コマンド: exit (終了), history (履歴), help (ヘルプ)"
  
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
      puts "会話を終了します。"
      break
      
    when 'history'
      puts "\n=== 会話履歴 ==="
      conversation_history.each do |msg|
        role = msg[:role]
        if msg[:parts].first.key?(:file_data)
          puts "[#{role}]: [ドキュメント]"
        else
          content_text = msg[:parts].map { |part| part[:text] }.join("\n")
          puts "[#{role}]: #{content_text}"
        end
        puts "--------------------------"
      end
      next
      
    when 'help'
      puts "\nコマンド:"
      puts "  exit    - 会話を終了"
      puts "  history - 会話履歴を表示"
      puts "  help    - このヘルプを表示"
      puts "  その他  - ドキュメントに関する質問"
      next
      
    when ''
      # 空の入力の場合はスキップ
      next
    end
    
    # ユーザーの質問を会話履歴に追加
    conversation_history << {
      role: "user",
      parts: [{ text: user_input }]
    }
    
    # Gemini APIに送信
    begin
      # 処理中の表示
      puts "処理中..."
      
      response = client.chat(parameters: {
        model: model,
        contents: conversation_history
      })
      
      if response.success?
        # 応答をログに追加
        conversation_history << {
          role: "model",
          parts: [{ text: response.text }]
        }
        
        # 応答を表示
        puts "\n[モデル]: #{response.text}"
      else
        puts "エラー: #{response.error || '不明なエラー'}"
      end
    rescue => e
      puts "エラーが発生しました: #{e.message}"
    end
  end

rescue StandardError => e
  logger.error "エラーが発生しました: #{e.message}"
  logger.error e.backtrace.join("\n") if ENV["DEBUG"]
end