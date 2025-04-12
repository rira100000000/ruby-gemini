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
def print_conversation(messages, show_all = false, skip_system = true, character_name)
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
  
  # システム指示を使用して応答を生成
  response = client.generate_content(
    initial_prompt,
    model: "gemini-2.0-flash-lite", # モデル名s
    system_instruction: system_instruction
  )
  
  # Responseクラスを使用して結果を処理
  if response.success?
    model_text = response.text
    
    # 会話履歴に追加
    conversation_history << { role: "user", content: initial_prompt }
    conversation_history << { role: "model", content: model_text }
    
    # 応答を表示
    puts "[#{character_name}]: #{model_text}"
  else
    logger.error "応答の生成に失敗しました: #{response.error || 'エラー詳細なし'}"
  end
  
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
      print_conversation(conversation_history, true, false, character_name)
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
    
    # システム指示を使用して応答を生成
    response = client.chat(parameters: {
      model: "gemini-2.0-flash", # モデル名
      system_instruction: { parts: [{ text: system_instruction }] },
      contents: contents
    })
    
    logger.info "Geminiからの応答を生成しています..."
    
    # Responseクラスを使用して応答を処理
    if response.success?
      model_text = response.text
      
      # 会話履歴に追加
      conversation_history << { role: "model", content: model_text }
      
      # 応答を表示
      puts "[#{character_name}]: #{model_text}"
    else
      logger.error "応答の生成に失敗しました: #{response.error || 'エラー詳細なし'}"
      puts "[#{character_name}]: すみません、応答を生成できませんでした。"
    end
  end
  
  logger.info "会話を終了します。"

rescue StandardError => e
  logger.error "エラーが発生しました: #{e.message}"
  logger.error e.backtrace.join("\n")
end