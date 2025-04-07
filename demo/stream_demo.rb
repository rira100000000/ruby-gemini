require 'bundler/setup'
require 'gemini'  # geminiライブラリを読み込む
require 'logger'
require 'readline' # コマンドライン編集機能のため

# ロガーの設定
logger = Logger.new(STDOUT)
logger.level = Logger::WARN

# APIキーを環境変数から取得、または直接指定
api_key = ENV['GEMINI_API_KEY'] || 'YOUR_API_KEY_HERE'
character_name = "モルすけ" 

# 会話の進行を表示する関数
def print_conversation(messages, show_all = false, skip_system = true, character_name)
  puts "\n=== 会話履歴 ==="
  
  # 表示するメッセージ
  display_messages = show_all ? messages["data"] : [messages["data"].last].compact
  
  # システムプロンプトをスキップする処理
  if skip_system && show_all && messages["data"].length >= 2
    # 最初の2メッセージ（システムプロンプトとその応答）をスキップ
    display_messages = messages["data"][2..-1]
  end
  
  display_messages.each do |message|
    role = message["role"]
    # メッセージの内容を取得（コンテンツの最初のテキスト要素）
    content_text = message["content"].first["text"]["value"] rescue "内容を取得できません"
    
    if role == "user"
      puts "[ユーザー]: " + content_text
    else
      puts "[#{character_name}]: " + content_text
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
  
  # スレッドの作成
  logger.info "新しい会話スレッドを作成しています..."
  response = client.threads.create
  thread_id = response["id"]
  logger.info "スレッドが作成されました: #{thread_id}"

  # 初期メッセージの追加（簡潔な返答を求める指示を含む）
  logger.info "初期設定メッセージを送信しています..."
  client.messages.create(
    thread_id: thread_id,
    parameters: {
      role: "user",
      content: "これから会話を始めます。あなたはかわいいモルモットのモルすけです。語尾に「モル」をつけ、かわいらしく振る舞ってください。あなたの返答は常に簡潔かつ要点をまとめた内容で、300文字以内にしてください。"
    }
  )
  
  # 応答を生成（ストリーミング形式）
  logger.info "初期応答を生成しています..."
  
  # 初期メッセージはプリントせずにバックグラウンドで生成
  client.runs.create(thread_id: thread_id)

  puts "\n#{character_name}との会話を始めます。"
  puts "コマンド:"
  puts "  exit    - 会話を終了"
  puts "  history - 会話履歴を表示（システム設定を除く）"
  puts "  all     - 全ての会話履歴（システム設定を含む）"
  puts "  help    - このヘルプを表示"
  
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
      puts "  history - 会話履歴を表示（システム設定を除く）"
      puts "  all     - 全ての会話履歴（システム設定を含む）"
      puts "  help    - このヘルプを表示"
      next
    end
    
    # 全履歴表示コマンド（システムメッセージを含む）
    if user_input.downcase == 'all'
      messages = client.messages.list(thread_id: thread_id)
      print_conversation(messages, true, false, character_name)  # skip_system = false
      next
    end
    
    # 履歴表示コマンド（システムメッセージを除く）
    if user_input.downcase == 'history'
      messages = client.messages.list(thread_id: thread_id)
      print_conversation(messages, true, true, character_name)  # skip_system = true
      next
    end
    
    # 空の入力はスキップ
    if user_input.empty?
      next
    end
    
    # ユーザー入力をメッセージとして追加
    logger.info "メッセージを送信しています..."
    message_response = client.messages.create(
      thread_id: thread_id,
      parameters: {
        role: "user",
        content: user_input
      }
    )
    
    # 応答を生成（ストリーミング形式）
    logger.info "Geminiからの応答を生成しています..."
    print "[#{character_name}]: "
    
    # ストリーミングコールバックを使用
    response_received = false
    
    client.runs.create(thread_id: thread_id) do |chunk|
      if chunk.to_s.strip.empty?
        next  # 空のチャンクはスキップ
      else
        response_received = true
        print chunk
        $stdout.flush
      end
    end
    
    # ストリーミングで何も受信しなかった場合、最新メッセージを表示
    if !response_received
      messages = client.messages.list(thread_id: thread_id)
      if messages["data"] && messages["data"].last && messages["data"].last["role"] == "model"
        content_text = messages["data"].last["content"].first["text"]["value"] rescue "内容を取得できません"
        print content_text
      end
    end
    
    puts "\n"
    logger.info "応答が生成されました"
  end
  
  logger.info "会話を終了します。スレッドID: #{thread_id}"

rescue StandardError => e
  logger.error "エラーが発生しました: #{e.message}"
  logger.error e.backtrace.join("\n")
end