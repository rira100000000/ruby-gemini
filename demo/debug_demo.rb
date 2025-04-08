require 'bundler/setup'
require 'faraday'
require 'json'
require 'dotenv/load'
require 'logger'
require 'readline'

# グローバルなロガーの設定
$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO

# 設定用の定数
API_BASE = "https://generativelanguage.googleapis.com/v1beta"
MODEL = "gemini-1.5-flash" # または "gemini-2.0-flash-lite" などモデル名を適宜変更
SYSTEM_PROMPT = "あなたはかわいいモルモットのモルすけです。語尾に「モル」をつけ、かわいらしく振る舞ってください。あなたの返答は常に簡潔かつ要点をまとめた内容で、300文字以内にしてください。"

# HTTPクライアント
def create_client
  Faraday.new do |conn|
    conn.options.timeout = 30
    conn.response :json
  end
end

# generateContent APIを直接呼び出す
def generate_content(client, content, api_key, system_instruction = nil)
  $logger.info "Gemini APIにリクエストを送信しています..."
  
  # リクエストパラメータを構築
  params = {
    contents: [
      {
        parts: [
          { text: content }
        ]
      }
    ],
    model: MODEL
  }
  
  # システムプロンプトが指定されている場合は追加
  if system_instruction
    params[:system_instruction] = {
      parts: [
        { text: system_instruction }
      ]
    }
  end
  
  # API呼び出し
  response = client.post("#{API_BASE}/models/#{MODEL}:generateContent?key=#{api_key}") do |req|
    req.headers['Content-Type'] = 'application/json'
    req.body = params.to_json
  end
  
  # レスポンスをパース
  if response.status == 200
    return response.body
  else
    $logger.error "APIエラー: #{response.status} - #{response.body}"
    return nil
  end
end

# ストリーミングバージョンのgenerateContent API呼び出し
def generate_content_stream(client, content, api_key, callback, system_instruction = nil)
  $logger.info "Gemini APIにストリーミングリクエストを送信しています..."
  
  # リクエストパラメータを構築
  params = {
    contents: [
      {
        parts: [
          { text: content }
        ]
      }
    ],
    model: MODEL
  }
  
  # システムプロンプトが指定されている場合は追加
  if system_instruction
    params[:system_instruction] = {
      parts: [
        { text: system_instruction }
      ]
    }
  end
  
  # ストリーミングのためのalt=sseパラメータを追加
  url = "#{API_BASE}/models/#{MODEL}:generateContent?key=#{api_key}&alt=sse"
  
  accumulated_text = ""
  
  # API呼び出し
  response = client.post(url) do |req|
    req.headers['Content-Type'] = 'application/json'
    req.options.on_data = proc do |chunk, _bytes, env|
      if env && env.status != 200
        $logger.error "ストリーミングエラー: #{env.status}"
        next
      end
      
      # SSEフォーマットを処理
      chunk.each_line do |line|
        if line.start_with?("data:")
          data = line[5..-1].strip
          next if data == "[DONE]"
          
          begin
            # JSONをパース
            parsed_data = JSON.parse(data)
            
            # テキスト部分を抽出
            if parsed_data.dig("candidates", 0, "content", "parts", 0, "text")
              text = parsed_data.dig("candidates", 0, "content", "parts", 0, "text")
              accumulated_text += text
              callback.call(text, accumulated_text)
            end
          rescue JSON::ParserError => e
            $logger.error "JSONパースエラー: #{e.message}"
          end
        end
      end
    end
    
    req.body = params.to_json
  end
  
  # レスポンスチェック
  if response.status != 200
    $logger.error "APIエラー: #{response.status} - #{response.body}"
    return nil
  end
  
  accumulated_text
end

# レスポンスからテキストを抽出
def extract_text(response)
  if response && response["candidates"] && !response["candidates"].empty?
    candidate = response["candidates"][0]
    if candidate["content"] && candidate["content"]["parts"] && !candidate["content"]["parts"].empty?
      return candidate["content"]["parts"][0]["text"]
    end
  end
  
  "応答テキストが見つかりません"
end

# メイン処理
def main
  # APIキーを環境変数から取得
  api_key = ENV['GEMINI_API_KEY'] || 'YOUR_API_KEY_HERE'
  character_name = "モルすけ"
  
  # 会話履歴
  conversation_history = []
  
  begin
    client = create_client
    
    puts "=== デバッグモード: Gemini APIと直接通信 ==="
    puts "モデル: #{MODEL}"
    puts "システムプロンプト: #{SYSTEM_PROMPT}"
    puts
    puts "コマンド:"
    puts "  exit       - 会話を終了"
    puts "  history    - 会話履歴を表示"
    puts "  debug      - デバッグ情報を表示"
    puts "  stream     - ストリーミングモードを切り替え（現在: OFF）"
    puts "  nosystem   - システムプロンプトを無効化（現在: ON）"
    puts
    
    # 最初の挨拶を生成
    puts "初期応答を生成しています..."
    response = generate_content(client, "こんにちは", api_key, SYSTEM_PROMPT)
    
    if response
      initial_text = extract_text(response)
      puts "[#{character_name}]: #{initial_text}"
      conversation_history << { role: "assistant", content: initial_text }
    else
      puts "初期応答の生成に失敗しました。"
    end
    
    # 会話ループの設定
    use_streaming = false
    use_system_prompt = true
    
    # コマンド補完用の設定
    commands = ['exit', 'history', 'debug', 'stream', 'nosystem']
    Readline.completion_proc = proc do |input|
      commands.grep(/^#{Regexp.escape(input)}/)
    end
    
    # 会話ループ
    loop do
      # ユーザー入力を取得
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
      
      # 履歴表示コマンド
      if user_input.downcase == 'history'
        puts "\n=== 会話履歴 ==="
        conversation_history.each do |msg|
          role_display = msg[:role] == "user" ? "ユーザー" : character_name
          puts "[#{role_display}]: #{msg[:content]}"
        end
        puts "===============\n"
        next
      end
      
      # デバッグ情報表示
      if user_input.downcase == 'debug'
        puts "\n=== デバッグ情報 ==="
        puts "モデル: #{MODEL}"
        puts "システムプロンプト: #{use_system_prompt ? SYSTEM_PROMPT : '無効'}"
        puts "ストリーミングモード: #{use_streaming ? 'ON' : 'OFF'}"
        puts "会話履歴数: #{conversation_history.size}"
        puts "===============\n"
        next
      end
      
      # ストリーミングモード切替
      if user_input.downcase == 'stream'
        use_streaming = !use_streaming
        puts "ストリーミングモードを#{use_streaming ? 'ON' : 'OFF'}に切り替えました。"
        next
      end
      
      # システムプロンプト切替
      if user_input.downcase == 'nosystem'
        use_system_prompt = !use_system_prompt
        puts "システムプロンプトを#{use_system_prompt ? 'ON' : 'OFF'}に切り替えました。"
        next
      end
      
      # 空の入力はスキップ
      if user_input.empty?
        next
      end
      
      # 会話履歴にユーザー入力を追加
      conversation_history << { role: "user", content: user_input }
      
      # APIでレスポンスを生成
      if use_streaming
        puts "[#{character_name}]: "
        final_text = generate_content_stream(
          client, 
          user_input,
          api_key,
          proc { |chunk, _| print chunk; $stdout.flush },
          use_system_prompt ? SYSTEM_PROMPT : nil
        )
        puts  # 改行
        
        # 会話履歴に応答を追加（ストリーミングの場合）
        if final_text
          conversation_history << { role: "assistant", content: final_text }
        end
      else
        # 通常の一括レスポンス
        response = generate_content(
          client, 
          user_input,
          api_key, 
          use_system_prompt ? SYSTEM_PROMPT : nil
        )
        
        if response
          response_text = extract_text(response)
          puts "[#{character_name}]: #{response_text}"
          conversation_history << { role: "assistant", content: response_text }
        else
          puts "応答の生成に失敗しました。"
        end
      end
    end
    
  rescue StandardError => e
    $logger.error "エラーが発生しました: #{e.message}"
    $logger.error e.backtrace.join("\n")
  end
end

# スクリプト実行
main