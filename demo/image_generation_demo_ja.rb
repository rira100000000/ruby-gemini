require 'bundler/setup'
require 'gemini'
require 'logger'

# ロガーの設定
logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# API レスポンスの保存
SAVE_RESPONSE = false

# APIキーを環境変数から取得
api_key = ENV['GEMINI_API_KEY'] || raise("GEMINI_API_KEY環境変数が設定されていません")

# Base64データを短縮表示するヘルパーメソッド
def deep_clone_and_truncate_base64(obj, max_length = 20)
  case obj
  when Hash
    result = {}
    obj.each do |k, v|
      # "data"キーや"bytesBase64Encoded"キーの内容は短縮する
      if (k == "data" || k == "bytesBase64Encoded") && v.is_a?(String) && v.length > max_length
        result[k] = "#{v[0...max_length]}...[Base64データ #{v.length} バイト]"
      else
        result[k] = deep_clone_and_truncate_base64(v, max_length)
      end
    end
    result
  when Array
    obj.map { |item| deep_clone_and_truncate_base64(item, max_length) }
  else
    obj
  end
end

begin
  # クライアントの初期化
  logger.info "Geminiクライアントを初期化しています..."
  client = Gemini::Client.new(api_key)
  
  puts "Gemini 画像生成デモ"
  puts "==================================="
  
  # プロンプトの入力受付
  puts "画像生成のためのプロンプトを入力してください："
  prompt = gets.chomp
  
  if prompt.empty?
    # デフォルトのプロンプト
    prompt = "青い空の下の美しい日本の桜の木"
    puts "プロンプトが入力されませんでした。デフォルトのプロンプトを使用します：\"#{prompt}\""
  end
  
  puts "\n使用するモデルを選択してください："
  puts "1. Gemini 2.0 (gemini-2.0-flash-exp-image-generation)"
  puts "2. Imagen 3 (imagen-3.0-generate-002) 注意:まだ動作確認していません"
  model_choice = gets.chomp.to_i
  model = case model_choice
          when 2
            "imagen-3.0-generate-002"
          else
            "gemini-2.0-flash-exp-image-generation"
          end

  puts "\n画像サイズを選択してください："
  puts "1. 正方形 (1:1)"
  puts "2. ポートレート (3:4)"
  puts "3. ランドスケープ (4:3)"
  puts "4. 縦長 (9:16)"
  puts "5. 横長 (16:9)"

  size_choice = gets.chomp.to_i
  size = case size_choice
         when 2
           "3:4"
         when 3
           "4:3"
         when 4
           "9:16"
         when 5
           "16:9"
         else
           "1:1"
         end

  # Imagen 3の場合は画像枚数も指定可能
  sample_count = 1
  if model.start_with?("imagen")
    puts "\n生成する画像の枚数を指定してください（1〜4）："
    sample_count = gets.chomp.to_i
    sample_count = [[sample_count, 1].max, 4].min # 1〜4の範囲に制限
  end

  # 出力ファイル名の設定
  timestamp = Time.now.strftime('%Y%m%d%H%M%S')
  output_dir = "generated_images"
  Dir.mkdir(output_dir) unless Dir.exist?(output_dir)

  # 処理開始時間
  start_time = Time.now

  puts "\n画像を生成しています..."

  # Images APIを使用して画像を生成
  response = client.images.generate(
    parameters: {
      prompt: prompt,
      model: model,
      size: size,
      n: sample_count
    }
  )

  # 処理終了時間と経過時間の計算
  end_time = Time.now
  elapsed_time = end_time - start_time
  
  # APIレスポンスをファイルに保存
  if SAVE_RESPONSE
    response_dir = "api_responses"
    Dir.mkdir(response_dir) unless Dir.exist?(response_dir)
    response_file = File.join(response_dir, "response_#{timestamp}.json")
    
    File.open(response_file, 'w') do |f|
      f.write(JSON.pretty_generate(response.raw_data))
    end
    
    puts "\nAPIレスポンスを保存しました: #{response_file}"
  end
  if response.success?
    # レスポンスの詳細をデバッグ出力 (Base64データを短縮表示)
    if ENV["DEBUG"]
      puts "\nレスポンスデータの構造:"
      # Base64データを短く表示するためのディープコピーを作成
      truncated_response = deep_clone_and_truncate_base64(response.raw_data)
      pp truncated_response
    end
    
    # 画像データを確認
    if !response.images.empty?
      puts "\n画像生成に成功しました！"
      
      # 生成された画像をファイルに保存
      filepaths = response.images.map.with_index do |_, i|
        File.join(output_dir, "#{timestamp}_#{i+1}.png")
      end
      
      saved_files = response.save_images(filepaths)
      
      puts "\n保存された画像ファイル："
      saved_files.each do |filepath|
        if filepath
          puts "- #{filepath}"
        else
          puts "- 保存に失敗した画像があります"
        end
      end
    else
      puts "\n画像データが見つかりません。テキストレスポンスのみかもしれません。"
    end
    
    # テキスト応答がある場合は表示
    if response.text && !response.text.empty?
      puts "\nモデルからのメッセージ："
      puts response.text
    end
  else
    puts "\n画像生成に失敗しました：#{response.error || '不明なエラー'}"
    # 詳細なエラー情報を表示
    puts "詳細なレスポンス情報："
    pp response.raw_data
  end

  puts "\n処理時間: #{elapsed_time.round(2)} 秒"

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