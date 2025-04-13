#!/usr/bin/env ruby
require 'bundler/setup'
require 'gemini'
require 'json'
require 'faraday'
require 'base64'
require 'readline'
require 'fileutils'
require 'time'

# APIキーを環境変数から取得
api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY環境変数を設定してください")

# キャッシュ情報を保存するファイル
cache_info_file = "gemini_cache_info.json"

# モード選択: 新規キャッシュ作成 or 既存キャッシュ利用
cache_mode = :create
cache_name = nil
model = "gemini-1.5-flash-001" # デフォルトモデル

if File.exist?(cache_info_file) && !ENV['FORCE_NEW_CACHE']
  begin
    # キャッシュ情報を読み込む
    cache_info = JSON.parse(File.read(cache_info_file))
    cache_name = cache_info["cache_name"]
    document_name = cache_info["document_name"]
    
    puts "既存のキャッシュ情報が見つかりました："
    puts "  キャッシュ名: #{cache_name}"
    puts "  ドキュメント: #{document_name}"
    
    # キャッシュの有効性を確認
    begin
      conn = Faraday.new do |f|
        f.options[:timeout] = 30
      end
      
      response = conn.get("https://generativelanguage.googleapis.com/v1beta/#{cache_name}") do |req|
        req.params['key'] = api_key
      end
      
      if response.status == 200
        cache_data = JSON.parse(response.body)
        if cache_data["expireTime"]
          expire_time = Time.parse(cache_data["expireTime"])
          current_time = Time.now
          
          puts "  有効期限: #{expire_time.strftime('%Y-%m-%d %H:%M:%S')}"
          puts "  現在時刻: #{current_time.strftime('%Y-%m-%d %H:%M:%S')}"
          
          if current_time < expire_time
            puts "キャッシュは有効です。再利用モードで起動します。"
            cache_mode = :reuse
            # モデル情報も取得
            model = cache_data["model"].sub("models/", "") if cache_data["model"]
            puts "  モデル: #{model}"
          else
            puts "キャッシュの有効期限が切れています。新規作成モードで起動します。"
          end
        else
          puts "キャッシュ情報の確認に失敗しました。新規作成モードで起動します。"
        end
      else
        puts "キャッシュの確認でエラーが発生しました（ステータス: #{response.status}）"
        puts "新規作成モードで起動します。"
      end
    rescue => e
      puts "キャッシュの確認中にエラーが発生しました: #{e.message}"
      puts "新規作成モードで起動します。"
    end
  rescue => e
    puts "キャッシュ情報の読み込みに失敗しました: #{e.message}"
    puts "新規作成モードで起動します。"
  end
else
  puts "キャッシュ情報が見つからないか、強制新規作成モードです。"
  puts "新規作成モードで起動します。"
end

puts "==================================="

# キャッシュ新規作成モードの場合
if cache_mode == :create
  # ドキュメントファイルのパスを指定
  file_path = ARGV[0] || raise("使用方法: ruby direct_cache_demo.rb <ドキュメントファイルのパス>")
  
  # ファイルの存在確認
  unless File.exist?(file_path)
    raise "ファイルが見つかりません: #{file_path}"
  end
  
  # ファイル情報を表示
  file_size = File.size(file_path) / 1024.0 # KB単位
  file_extension = File.extname(file_path)
  document_name = File.basename(file_path)
  puts "ファイル: #{document_name}"
  puts "サイズ: #{file_size.round(2)} KB"
  puts "タイプ: #{file_extension}"
  puts "==================================="
  
  # 処理開始時間
  start_time = Time.now
  
  # MIMEタイプを決定
  mime_type = case file_extension.downcase
              when '.pdf'
                'application/pdf'
              when '.txt'
                'text/plain'
              when '.html', '.htm'
                'text/html'
              when '.csv'
                'text/csv'
              when '.md'
                'text/md'
              when '.js'
                'application/x-javascript'
              when '.py'
                'application/x-python'
              else
                'application/octet-stream'
              end
  
  puts "ドキュメントをキャッシュに保存中..."
  puts "MIMEタイプ: #{mime_type}"
  
  # ファイルサイズが大きい場合の警告
  if file_size > 10000 # 10MB以上
    puts "警告: ファイルサイズが大きいため、処理に時間がかかる場合があります。"
    puts "処理中は辛抱強くお待ちください..."
  end

  # 大きなファイルの処理を監視するためのプログレスインジケータを表示
  progress_thread = Thread.new do
    spinner = ['|', '/', '-', '\\']
    i = 0
    loop do
      print "\r処理中... #{spinner[i]} "
      i = (i + 1) % 4
      sleep 0.5
    end
  end
  
  begin
    # ファイルを読み込みBase64エンコード
    file_data = File.binread(file_path)
    encoded_data = Base64.strict_encode64(file_data)
    
    # キャッシュリクエストを準備
    request = {
      "model" => "models/#{model}",
      "contents" => [
        {
          "parts" => [
            {
              "inline_data" => {
                "mime_type" => mime_type,
                "data" => encoded_data
              }
            }
          ],
          "role" => "user"
        }
      ],
      "systemInstruction" => {
        "parts" => [
          {
            "text" => "あなたはドキュメント分析の専門家です。与えられたドキュメントの内容を正確に把握し、質問に詳細に答えてください。"
          }
        ],
        "role" => "system"
      },
      "ttl" => "86400s" # 24時間
    }
    
    # Faradayインスタンスを作成（タイムアウト延長）
    conn = Faraday.new do |f|
      f.options[:timeout] = 300 # 5分タイムアウト
    end
    
    # APIリクエストを送信
    response = conn.post("https://generativelanguage.googleapis.com/v1beta/cachedContents") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.params['key'] = api_key
      req.body = JSON.generate(request)
    end
    
    # プログレススレッドを終了
    progress_thread.kill
    print "\r" # カーソルを行頭に戻す
    
    if response.status == 200
      result = JSON.parse(response.body)
      cache_name = result["name"]
      
      # キャッシュ情報をJSONに保存（再利用のため）
      cache_info = {
        "cache_name" => cache_name,
        "document_name" => document_name,
        "created_at" => Time.now.to_s,
        "file_path" => file_path,
        "model" => model
      }
      
      File.write(cache_info_file, JSON.pretty_generate(cache_info))
      
      # 処理終了時間と経過時間の計算
      end_time = Time.now
      elapsed_time = end_time - start_time
      
      puts "成功！ドキュメントがキャッシュに保存されました。"
      puts "キャッシュ名: #{cache_name}"
      puts "処理時間: #{elapsed_time.round(2)} 秒"
      
      # トークン使用量情報（利用可能な場合）
      if result["usageMetadata"] && result["usageMetadata"]["totalTokenCount"]
        token_count = result["usageMetadata"]["totalTokenCount"]
        puts "トークン使用量: #{token_count}"
        
        if token_count < 32768
          puts "警告: トークン数が最小要件（32,768）を下回っています。キャッシュが正常に機能しない可能性があります。"
        else
          puts "トークン数は最小要件（32,768）を満たしています。"
        end
      end
    else
      puts "エラー: キャッシュの作成に失敗しました（ステータスコード: #{response.status}）"
      if response.body
        begin
          error_json = JSON.parse(response.body)
          puts JSON.pretty_generate(error_json)
        rescue
          puts response.body
        end
      end
      exit 1
    end
  rescue => e
    # プログレススレッドを終了
    progress_thread.kill if progress_thread.alive?
    print "\r" # カーソルを行頭に戻す
    puts "エラーが発生しました: #{e.message}"
    exit 1
  end
else
  # 再利用モードの場合はキャッシュ情報を読み込んだものを使用
  puts "既存のキャッシュを再利用します: #{cache_name}"
  puts "使用するモデル: #{model}"
end

puts "==================================="

# コマンド補完用の設定
COMMANDS = ['exit', 'list', 'delete', 'help', 'info', 'extend'].freeze
Readline.completion_proc = proc { |input|
  COMMANDS.grep(/^#{Regexp.escape(input)}/)
}

puts "\nキャッシュされたドキュメントに質問できます。"
puts "コマンド: exit (終了), list (一覧), delete (削除), info (情報), extend (有効期限延長), help (ヘルプ)"

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
    conn = Faraday.new
    response = conn.get("https://generativelanguage.googleapis.com/v1beta/cachedContents") do |req|
      req.params['key'] = api_key
    end
    
    if response.status == 200
      result = JSON.parse(response.body)
      if result["cachedContents"] && !result["cachedContents"].empty?
        result["cachedContents"].each do |cache|
          puts "名前: #{cache['name']}"
          puts "モデル: #{cache['model']}"
          puts "作成時間: #{Time.parse(cache['createTime']).strftime('%Y-%m-%d %H:%M:%S')}" if cache['createTime']
          puts "有効期限: #{Time.parse(cache['expireTime']).strftime('%Y-%m-%d %H:%M:%S')}" if cache['expireTime']
          puts "トークン数: #{cache.dig('usageMetadata', 'totalTokenCount') || '不明'}"
          puts "--------------------------"
        end
      else
        puts "キャッシュが見つかりません。"
      end
    else
      puts "キャッシュ一覧の取得に失敗しました（ステータスコード: #{response.status}）"
    end
    next
    
  when 'delete'
    puts "\nキャッシュを削除します: #{cache_name}"
    conn = Faraday.new
    response = conn.delete("https://generativelanguage.googleapis.com/v1beta/#{cache_name}") do |req|
      req.params['key'] = api_key
    end
    
    if response.status == 200
      puts "キャッシュが削除されました。"
      # キャッシュ情報ファイルも削除
      FileUtils.rm(cache_info_file) if File.exist?(cache_info_file)
      puts "キャッシュ情報ファイルも削除しました。"
      puts "デモを終了します。"
      break
    else
      puts "キャッシュの削除に失敗しました（ステータスコード: #{response.status}）"
    end
    next
    
  when 'info'
    puts "\n=== 現在のキャッシュ情報 ==="
    conn = Faraday.new
    response = conn.get("https://generativelanguage.googleapis.com/v1beta/#{cache_name}") do |req|
      req.params['key'] = api_key
    end
    
    if response.status == 200
      cache_data = JSON.parse(response.body)
      puts "キャッシュ名: #{cache_data['name']}"
      puts "モデル: #{cache_data['model']}"
      
      if cache_data["createTime"]
        create_time = Time.parse(cache_data["createTime"])
        puts "作成時間: #{create_time.strftime('%Y-%m-%d %H:%M:%S')}"
      end
      
      if cache_data["expireTime"]
        expire_time = Time.parse(cache_data["expireTime"])
        current_time = Time.now
        remaining_time = expire_time - current_time
        puts "有効期限: #{expire_time.strftime('%Y-%m-%d %H:%M:%S')}"
        
        # 残り時間を日時分秒で表示
        days = (remaining_time / 86400).to_i
        hours = ((remaining_time % 86400) / 3600).to_i
        minutes = ((remaining_time % 3600) / 60).to_i
        seconds = (remaining_time % 60).to_i
        
        puts "残り時間: #{days}日 #{hours}時間 #{minutes}分 #{seconds}秒"
      end
      
      if cache_data.dig("usageMetadata", "totalTokenCount")
        token_count = cache_data['usageMetadata']['totalTokenCount']
        puts "トークン数: #{token_count}"
        
        if token_count < 32768
          puts "警告: トークン数が最小要件（32,768）を下回っています。"
        else
          puts "トークン数は最小要件（32,768）を満たしています。"
        end
      end
    else
      puts "キャッシュ情報の取得に失敗しました（ステータスコード: #{response.status}）"
    end
    next
    
  when 'extend'
    puts "\nキャッシュの有効期限を延長します: #{cache_name}"
    conn = Faraday.new
    response = conn.patch("https://generativelanguage.googleapis.com/v1beta/#{cache_name}") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.params['key'] = api_key
      req.params['updateMask'] = 'ttl'
      req.body = JSON.generate({ "ttl" => "86400s" }) # 24時間延長
    end
    
    if response.status == 200
      result = JSON.parse(response.body)
      if result["expireTime"]
        expire_time = Time.parse(result["expireTime"])
        puts "有効期限が延長されました: #{expire_time.strftime('%Y-%m-%d %H:%M:%S')}"
      else
        puts "有効期限の延長に成功しましたが、新しい有効期限が取得できませんでした。"
      end
    else
      puts "有効期限の延長に失敗しました（ステータスコード: #{response.status}）"
    end
    next
    
  when 'help'
    puts "\nコマンド:"
    puts "  exit   - デモを終了"
    puts "  list   - キャッシュ一覧を表示"
    puts "  delete - 現在のキャッシュを削除"
    puts "  info   - 現在のキャッシュの詳細情報を表示"
    puts "  extend - キャッシュの有効期限を24時間延長"
    puts "  help   - このヘルプを表示"
    puts "  その他 - ドキュメントに関する質問"
    next
    
  when ''
    # 空の入力の場合はスキップ
    next
  end
  
  # 質問処理
  begin
    # 処理時間計測開始
    query_start_time = Time.now
    
    # 処理中の表示
    puts "処理中..."
    
    # 質問リクエストを準備
    request = {
      "contents" => [
        {
          "parts" => [
            { "text" => user_input }
          ],
          "role" => "user"
        }
      ],
      "cachedContent" => cache_name
    }
    
    # APIリクエストを送信
    conn = Faraday.new do |f|
      f.options[:timeout] = 60
    end
    
    response = conn.post("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.params['key'] = api_key
      req.body = JSON.generate(request)
    end
    
    # 処理時間計測終了
    query_end_time = Time.now
    query_time = query_end_time - query_start_time
    
    if response.status == 200
      result = JSON.parse(response.body)
      
      # テキスト応答を抽出
      answer_text = nil
      if result["candidates"] && !result["candidates"].empty?
        candidate = result["candidates"][0]
        if candidate["content"] && candidate["content"]["parts"]
          parts = candidate["content"]["parts"]
          texts = parts.map { |part| part["text"] }.compact
          answer_text = texts.join("\n")
        end
      end
      
      if answer_text
        puts "\n回答:"
        puts answer_text
        puts "\n処理時間: #{query_time.round(2)} 秒"
        
        # トークン使用量情報（利用可能な場合）
        if result["usage"]
          puts "トークン使用量:"
          puts "  プロンプト: #{result['usage']['promptTokens'] || 'N/A'}"
          puts "  生成: #{result['usage']['candidateTokens'] || 'N/A'}"
          puts "  合計: #{result['usage']['totalTokens'] || 'N/A'}"
        end
      else
        puts "エラー: 応答からテキストを抽出できませんでした"
        puts "応答内容:"
        puts JSON.pretty_generate(result)
      end
    else
      puts "エラー: 質問処理に失敗しました（ステータスコード: #{response.status}）"
      if response.body
        begin
          error_json = JSON.parse(response.body)
          puts JSON.pretty_generate(error_json)
        rescue
          puts response.body
        end
      end
    end
  rescue => e
    puts "質問の処理中にエラーが発生しました: #{e.message}"
  end
end