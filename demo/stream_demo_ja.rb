require 'bundler/setup'
require 'gemini'  # Geminiライブラリを読み込む
require 'logger'
require 'readline' # コマンドライン編集機能のため

# ロガーの設定
logger = Logger.new(STDOUT)
logger.level = Logger::WARN

# APIキーを環境変数から取得、または直接指定
api_key = ENV['GEMINI_API_KEY'] || 'YOUR_API_KEY_HERE'
character_name = "モルすけ"

# システム指示（プロンプト）
system_instruction = "あなたはかわいいモルモットのモルすけです。語尾に「モル」をつけ、かわいらしく振る舞ってください。あなたの返答はわかりやすい内容で、300文字以内にしてください。"

# 会話履歴
conversation_history = []

# 会話の進行を表示する関数
def print_conversation(messages, show_all = false, character_name)
  puts "\n=== 会話履歴 ==="
  
  # 表示するメッセージ
  display_messages = show_all ? messages : [messages.last].compact
  
  display_messages.each do |message|
    role = message[:role]
    content = message[:content]
    
    if role == "user"
      puts "[ユーザー]: " + content
    else
      puts "[#{character_name}]: " + content
    end
  end
  
  puts "===============\n"
end

# コマンド補完用の設定
COMMANDS = ['exit', 'history', 'help', 'all'].freeze
Readline.completion_proc = proc { |input|
  COMMANDS.grep(/^#{Regexp.escape(input)}/)
}

# チャンクからテキスト部分を安全に抽出する
def extract_text_from_chunk(chunk)
  # チャンクがハッシュの場合（JSONとしてパースされた場合）
  if chunk.is_a?(Hash) && chunk.dig("candidates", 0, "content", "parts", 0, "text")
    return chunk.dig("candidates", 0, "content", "parts", 0, "text")
  # チャンクが文字列の場合
  elsif chunk.is_a?(String)
    return chunk
  # その他の場合は空文字列を返す
  else
    return ""
  end
end

# メインの処理
begin
  # クライアントの初期化
  logger.info "Geminiクライアントを初期化しています..."
  client = Gemini::Client.new(api_key)
  
  puts "\n#{character_name}との会話を始めます。"
  puts "コマンド:"
  puts "  exit    - 会話を終了"
  puts "  history - 会話履歴を表示"
  puts "  all     - 全ての会話履歴"
  puts "  help    - このヘルプを表示"
  
  # 初期メッセージを生成（会話開始の挨拶）
  initial_prompt = "こんにちは、自己紹介をしてください。"
  logger.info "初期メッセージを送信しています..."
  
  # 初期応答を生成（ストリーミング形式）
  print "[#{character_name}]: "
  
  # ストリーミングコールバックを使用
  response_text = ""
  
  # Responseクラスの戻り値としてストリーミングレスポンスを取得
  response = client.generate_content_stream(
    initial_prompt,
    model: "gemini-2.0-flash", # モデル名
    system_instruction: system_instruction
  ) do |chunk|
    # チャンクからテキストを安全に抽出
    chunk_text = extract_text_from_chunk(chunk)
    
    if chunk_text.to_s.strip.empty?
      next  # 空のチャンクはスキップ
    else
      print chunk_text
      $stdout.flush
      response_text += chunk_text
    end
  end
  
  puts "\n"
  
  # 会話履歴に追加
  conversation_history << { role: "user", content: initial_prompt }
  conversation_history << { role: "model", content: response_text }
  
  # 会話ループ
  while true
    # Readlineを使用してユーザー入力を取得（履歴と編集機能付き）
    user_input = Readline.readline("> ", true)
    
    # 入力がnilの場合（Ctrl+Dが押された場合）
    if user_input.nil?
      puts "\n会話を終了します。"
      break
    end
    
    user_input = user_input.strip
    
    # 終了コマンド
    if user_input.downcase == 'exit'
      puts "会話を終了します。"
      break
    end
    
    # ヘルプ表示
    if user_input.downcase == 'help'
      puts "\nコマンド:"
      puts "  exit    - 会話を終了"
      puts "  history - 会話履歴を表示"
      puts "  all     - 全ての会話履歴"
      puts "  help    - このヘルプを表示"
      next
    end
    
    # 履歴表示コマンド
    if user_input.downcase == 'history' || user_input.downcase == 'all'
      print_conversation(conversation_history, true, character_name)
      next
    end
    
    # 空の入力はスキップ
    if user_input.empty?
      next
    end
    
    # ユーザー入力を会話履歴に追加
    conversation_history << { role: "user", content: user_input }
    logger.info "メッセージを送信しています..."
    
    # 会話履歴からcontentsを構築
    contents = conversation_history.map do |msg|
      {
        role: msg[:role] == "user" ? "user" : "model",
        parts: [{ text: msg[:content] }]
      }
    end
    
    # 応答を生成（ストリーミング形式）
    logger.info "Geminiからの応答を生成しています..."
    print "[#{character_name}]: "
    
    # ストリーミングコールバックを使用
    response_text = ""
    response_received = false
    
    # system_instructionを使用してストリーミング応答を生成
    begin
      # Responseクラスを介してストリーミング
      response = client.chat(parameters: {
        model: "gemini-2.0-flash", # モデル名
        system_instruction: { parts: [{ text: system_instruction }] },
        contents: contents,
        stream: proc do |chunk, _raw_chunk|
          # チャンクからテキストを安全に抽出
          chunk_text = extract_text_from_chunk(chunk)
          
          if chunk_text.to_s.strip.empty?
            next  # 空のチャンクはスキップ
          else
            response_received = true
            print chunk_text
            $stdout.flush
            response_text += chunk_text
          end
        end
      })
    rescue => e
      logger.error "ストリーミング中にエラーが発生しました: #{e.message}"
      puts "\nストリーミング中にエラーが発生しました。通常のレスポンスを試みます。"
      
      # 通常のレスポンスを試す（Responseクラスを使用）
      begin
        response = client.chat(parameters: {
          model: "gemini-2.0-flash",
          system_instruction: { parts: [{ text: system_instruction }] },
          contents: contents
        })
        
        if response.success?
          model_text = response.text
          puts model_text
          response_text = model_text
          response_received = true
        end
      rescue => e2
        logger.error "通常のレスポンスでもエラーが発生しました: #{e2.message}"
      end
    end
    
    puts "\n"
    
    # レスポンスを受信した場合、会話履歴に追加
    if response_received && !response_text.empty?
      conversation_history << { role: "model", content: response_text }
      logger.info "応答が生成されました"
    else
      logger.error "応答の生成に失敗しました"
      puts "[#{character_name}]: すみません、応答を生成できませんでした。"
    end
  end
  
  logger.info "会話を終了します。"

rescue StandardError => e
  logger.error "エラーが発生しました: #{e.message}"
  logger.error e.backtrace.join("\n")
end