# Ruby-Gemini-API

Google のGemini API用Rubyクライアントライブラリです。このgemは、Geminiの生成AI機能と対話するためのシンプルで直感的なインターフェースを提供し、他のAIクライアントライブラリと同様のパターンに従っています。

このプロジェクトは[ruby-openai](https://github.com/alexrudall/ruby-openai)にインスパイアされており、GeminiのAIモデルを扱うRuby開発者に親しみやすく一貫性のある体験を提供することを目指しています。

## 機能

- Geminiモデルによるテキスト生成
- 会話履歴付きのチャット機能
- リアルタイムなテキスト生成のためのストリーミングレスポンス
- 音声文字起こし機能
- チャットアプリケーション用のスレッドとメッセージ管理
- AIタスク実行のためのRun管理
- 便利なResponseオブジェクト
- JSONスキーマとenum制約による構造化出力
- PDF等のドキュメント処理
- コンテキストキャッシュによる処理の効率化

## インストール

アプリケーションのGemfileにこの行を追加します：

```ruby
gem 'ruby-gemini-api'
```

そして、次を実行します：

```bash
$ bundle install
```

または、自分でインストールすることもできます：

```bash
$ gem install ruby-gemini-api
```

## クイックスタート

### テキスト生成

```ruby
require 'gemini'

# APIキーでクライアントを初期化
client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# テキストを生成
response = client.generate_content(
  "Rubyプログラミング言語の主な特徴は何ですか？",
  model: "gemini-2.0-flash-lite"
)

# Responseオブジェクトを使用して生成されたコンテンツにアクセス
if response.valid?
  puts response.text
else
  puts "エラー: #{response.error}"
end
```

### ストリーミングテキスト生成

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# リアルタイムでレスポンスをストリーミング
client.generate_content_stream(
  "Rubyが大好きなプログラマーについての物語を教えてください",
  model: "gemini-2.0-flash-lite"
) do |chunk|
  print chunk
  $stdout.flush
end
```

### チャット会話

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# 会話コンテンツを作成
contents = [
  { role: "user", parts: [{ text: "こんにちは、Rubyについて学びたいと思っています。" }] },
  { role: "model", parts: [{ text: "素晴らしいですね！Rubyは動的で解釈型の言語で..." }] },
  { role: "user", parts: [{ text: "Rubyが他の言語と異なる点は何ですか？" }] }
]

# 会話履歴でレスポンスを取得
response = client.chat(parameters: {
  model: "gemini-2.0-flash-lite",
  contents: contents
})

# Responseオブジェクトを使用してレスポンスを処理
if response.success?
  puts response.text
else
  puts "エラー: #{response.error}"
end

# その他のレスポンス情報にもアクセス可能
puts "終了理由: #{response.finish_reason}"
puts "トークン使用量: #{response.total_tokens}"
```

### システムインストラクションの使用

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# モデルの動作に関するシステムインストラクションを設定
system_instruction = "あなたは簡潔なコード例を提供するRubyプログラミングの専門家です。"

# チャットでシステムインストラクションを使用
response = client.chat(parameters: {
  model: "gemini-2.0-flash-lite",
  system_instruction: { parts: [{ text: system_instruction }] },
  contents: [{ role: "user", parts: [{ text: "Rubyでシンプルなウェブサーバーを書くにはどうすればいいですか？" }] }]
})

# レスポンスにアクセス
puts response.text

# レスポンスが安全上の理由でブロックされたかどうかを確認
if response.safety_blocked?
  puts "レスポンスは安全上の考慮によりブロックされました"
end
```

### 画像認識

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# 画像ファイルを分析（注：直接アップロードの場合、ファイルサイズ制限は20MBです）
response = client.generate_content(
  [
    { type: "text", text: "この画像に何が見えるか説明してください" },
    { type: "image_file", image_file: { file_path: "path/to/image.jpg" } }
  ],
  model: "gemini-2.0-flash"
)

# Responseオブジェクトを使用して説明にアクセス
if response.success?
  puts response.text
else
  puts "画像分析に失敗しました: #{response.error}"
end
```

20MB以上の画像ファイルの場合は、`files.upload`メソッドを使用する必要があります：

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# 大きな画像ファイルをアップロード
file = File.open("path/to/large_image.jpg", "rb")
upload_result = client.files.upload(file: file)
# レスポンスからファイルURIと名前を取得
file_uri = upload_result["file"]["uri"]
file_name = upload_result["file"]["name"]

# 画像分析にファイルURIを使用
response = client.generate_content(
  [
    { text: "この画像を詳細に説明してください" },
    { file_data: { mime_type: "image/jpeg", file_uri: file_uri } }
  ],
  model: "gemini-2.0-flash"
)

# Responseオブジェクトを使用してレスポンスを処理
if response.success?
  puts response.text
else
  puts "画像分析に失敗しました: #{response.error}"
end

# 終了時にファイルを削除（オプション）
client.files.delete(name: file_name)
```

より詳しい例は、gemに含まれる`demo/vision_demo_ja.rb`と`demo/file_vision_demo_ja.rb`ファイルをご覧ください。

### 画像生成

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# Gemini 2.0を使用して画像を生成
response = client.images.generate(
  parameters: {
    prompt: "セーリングボートのある海の上の美しい夕日",
    model: "gemini-2.0-flash-exp-image-generation",
    size: "16:9"
  }
)

# 生成された画像を保存
if response.success? && !response.images.empty?
  filepath = "generated_image.png"
  response.save_image(filepath)
  puts "画像が#{filepath}に保存されました"
else
  puts "画像生成に失敗しました: #{response.error}"
end
```

Imagen 3モデルも使用できます（注：この機能はまだ完全にテストされていません）：

```ruby
# Imagen 3を使用して複数画像を生成
response = client.images.generate(
  parameters: {
    prompt: "空飛ぶ車と高層ビルのある未来都市",
    model: "imagen-3.0-generate-002",
    size: "1:1",
    n: 4  # 4枚の画像を生成
  }
)

# すべての生成画像を保存
if response.success? && !response.images.empty?
  filepaths = response.images.map.with_index { |_, i| "imagen_#{i+1}.png" }
  saved_files = response.save_images(filepaths)
  saved_files.each { |f| puts "画像が#{f}に保存されました" if f }
end
```

完全な例は、gemに含まれる`demo/image_generation_demo_ja.rb`ファイルをご覧ください。

### 音声文字起こし

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# 音声ファイルを文字起こし（注：直接アップロードの場合、ファイルサイズ制限は20MBです）
response = client.audio.transcribe(
  parameters: {
    model: "gemini-1.5-flash",
    file: File.open("audio_file.mp3", "rb"),
    language: "ja",
    content_text: "この音声クリップを文字起こししてください"
  }
)

# Responseオブジェクトを使用して文字起こしに簡単にアクセス
if response.success?
  puts response.text
else
  puts "文字起こしに失敗しました: #{response.error}"
end
```

20MB以上の音声ファイルの場合は、`files.upload`メソッドを使用する必要があります：

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# 大きな音声ファイルをアップロード
file = File.open("path/to/audio.mp3", "rb")
upload_result = client.files.upload(file: file)
# レスポンスからファイルURIと名前を取得
file_uri = upload_result["file"]["uri"]
file_name = upload_result["file"]["name"]

# 文字起こしにファイルIDを使用
response = client.audio.transcribe(
  parameters: {
    model: "gemini-1.5-flash",
    file_uri: file_uri,
    language: "ja"
  }
)

# レスポンスが成功したかどうかを確認し、文字起こしを取得
if response.success?
  puts response.text
else
  puts "文字起こしに失敗しました: #{response.error}"
end

# 終了時にファイルを削除（オプション）
client.files.delete(name: file_name)
```

より詳しい例は、gemに含まれる`demo/file_audio_demo_ja.rb`ファイルをご覧ください。

### ドキュメント処理

Gemini APIは、PDFなどの長いドキュメント（最大3,600ページ）を処理することができます。ドキュメント内のテキストと画像の両方の内容を理解し、分析、要約、質問応答などを行うことができます。

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# PDFドキュメントを処理
result = client.documents.process(
  file_path: "path/to/document.pdf",
  prompt: "このドキュメントの主要なポイントを3つ要約してください",
  model: "gemini-1.5-flash"
)

response = result[:response]

# レスポンスを確認
if response.success?
  puts response.text
else
  puts "ドキュメント処理に失敗しました: #{response.error}"
end

# ファイル情報（オプション）
puts "ファイルURI: #{result[:file_uri]}"
puts "ファイル名: #{result[:file_name]}"
```

より複雑なドキュメント処理には、会話形式でドキュメントについて質問することもできます：

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# ドキュメントとの会話を開始
file_path = "path/to/document.pdf"
thread_result = client.chat_with_file(
  file_path,
  "このドキュメントの概要を教えてください",
  model: "gemini-1.5-flash"
)

# スレッドIDを取得（続きの会話に使用）
thread_id = thread_result[:thread_id]

# メッセージを追加して会話を続ける
client.messages.create(
  thread_id: thread_id,
  parameters: {
    role: "user",
    content: "さらに詳しく教えてください"
  }
)

# 実行して応答を取得
run = client.runs.create(thread_id: thread_id)

# 会話履歴を取得
messages = client.messages.list(thread_id: thread_id)
puts "会話履歴:"
messages["data"].each do |msg|
  role = msg["role"]
  content = msg["content"].map { |c| c["text"]["value"] }.join("\n")
  puts "#{role.upcase}: #{content}"
  puts "--------------------------"
end
```

サポートされているドキュメント形式:
- PDF - application/pdf
- テキスト - text/plain
- HTML - text/html
- CSS - text/css
- マークダウン - text/md
- CSV - text/csv
- XML - text/xml
- RTF - text/rtf
- JavaScript - application/x-javascript、text/javascript
- Python - application/x-python、text/x-python

デモアプリケーションは `demo/document_chat_demo.rb` および `demo/document_conversation_demo.rb` でご確認いただけます。

### コンテキストキャッシュ

コンテキストキャッシュを使用すると、大きなドキュメントや画像などの入力をGemini APIに事前処理させて保存し、繰り返し使用することができます。これにより、同じファイルに対して複数の質問を行う際に処理時間とトークン使用量を節約できます。

**重要**: コンテキストキャッシュには最小入力トークン数が32,768必要です。最大トークン数は使用するモデルのコンテキストウィンドウサイズと同じです。キャッシュは48時間後に自動的に削除されますが、TTL（Time To Live）を設定して延長することもできます。モデルは固定バージョンの安定版モデル（gemini-1.5-pro-001 など）でのみ使用できます。バージョンの接尾辞（gemini-1.5-pro-001 の -001 など）を含める必要があります。

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# ドキュメントをキャッシュに保存
cache_result = client.documents.cache(
  file_path: "path/to/large_document.pdf",
  system_instruction: "あなたはドキュメント分析エキスパートです。ドキュメントの内容を詳細に理解し、質問に正確に答えてください。",
  ttl: "86400s", # 24時間（秒単位）
  model: "gemini-1.5-flash-001"
)

# キャッシュ名を取得
cache_name = cache_result[:cache][:name]
puts "キャッシュ名: #{cache_name}"

# キャッシュを使用して質問
response = client.generate_content_with_cache(
  "このドキュメントの主要な発見事項は何ですか？",
  cached_content: cache_name,
  model: "gemini-1.5-flash-001"
)

if response.success?
  puts response.text
else
  puts "エラー: #{response.error}"
end

# キャッシュの有効期限を延長
client.cached_content.update(
  name: cache_name,
  ttl: "172800s" # 48時間（秒単位）
)

# キャッシュを削除（使用後）
client.cached_content.delete(name: cache_name)
```

キャッシュの一覧を取得することもできます：

```ruby
# すべてのキャッシュを一覧表示
caches = client.cached_content.list
puts "キャッシュ一覧:"
caches.raw_data["cachedContents"].each do |cache|
  puts "名前: #{cache['name']}"
  puts "モデル: #{cache['model']}"
  puts "有効期限: #{cache['expireTime']}"
  puts "トークン数: #{cache.dig('usageMetadata', 'totalTokenCount')}"
  puts "--------------------------"
end
```

コンテキストキャッシュのデモは `demo/document_cache_demo.rb` でご確認いただけます。

### JSONスキーマによる構造化出力

JSONスキーマを指定することで、構造化されたJSON形式でレスポンスを要求できます：

```ruby
require 'gemini'
require 'json'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# レシピ用のスキーマを定義
recipe_schema = {
  type: "ARRAY",
  items: {
    type: "OBJECT",
    properties: {
      "recipe_name": { type: "STRING" },
      "ingredients": {
        type: "ARRAY",
        items: { type: "STRING" }
      },
      "preparation_time": {
        type: "INTEGER",
        description: "調理時間（分）"
      }
    },
    required: ["recipe_name", "ingredients"],
    propertyOrdering: ["recipe_name", "ingredients", "preparation_time"]
  }
}

# スキーマに従ったJSON形式のレスポンスをリクエスト
response = client.generate_content(
  "材料と調理時間を含む人気のクッキーレシピを3つ紹介してください",
  response_mime_type: "application/json",
  response_schema: recipe_schema
)

# JSONレスポンスを処理
if response.success? && response.json?
  recipes = response.json
  
  # 構造化データの活用
  recipes.each do |recipe|
    puts "#{recipe['recipe_name']} (#{recipe['preparation_time']}分)"
    puts "材料: #{recipe['ingredients'].join(', ')}"
    puts
  end
else
  puts "JSONの取得に失敗しました: #{response.error}"
end
```

### 列挙型で制約されたレスポンス

enumを使用してレスポンスの可能な値を制限できます：

```ruby
require 'gemini'
require 'json'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# 列挙型制約付きのスキーマを定義
review_schema = {
  type: "OBJECT",
  properties: {
    "product_name": { type: "STRING" },
    "rating": {
      type: "STRING",
      enum: ["1", "2", "3", "4", "5"],
      description: "1から5までの評価"
    },
    "recommendation": {
      type: "STRING",
      enum: ["おすすめしない", "どちらでもない", "おすすめする", "強くおすすめする"],
      description: "おすすめ度"
    },
    "comment": { type: "STRING" }
  },
  required: ["product_name", "rating", "recommendation"]
}

# 制約付きレスポンスをリクエスト
response = client.generate_content(
  "新型スマートフォン「GeminiPhone 15」のレビューを書いてください",
  response_mime_type: "application/json",
  response_schema: review_schema
)

# 制約に従った構造化データの活用
if response.success? && response.json?
  review = response.json
  puts "製品: #{review['product_name']}"
  puts "評価: #{review['rating']}/5"
  puts "おすすめ度: #{review['recommendation']}"
  puts "コメント: #{review['comment']}" if review['comment']
else
  puts "JSONの取得に失敗しました: #{response.error}"
end
```

構造化出力の完全な例は、gemに含まれる`demo/structured_output_demo_ja.rb`と`demo/enum_response_demo_ja.rb`ファイルをご覧ください。

## 高度な使用方法

### スレッドとメッセージ

このライブラリは、他のAIプラットフォームと同様のスレッドとメッセージの概念をサポートしています：

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

# 新しいスレッドを作成
thread = client.threads.create(parameters: { model: "gemini-2.0-flash-lite" })
thread_id = thread["id"]

# スレッドにメッセージを追加
message = client.messages.create(
  thread_id: thread_id,
  parameters: {
    role: "user",
    content: "Ruby on Railsについて教えてください"
  }
)

# スレッドでRunを実行
run = client.runs.create(thread_id: thread_id)

# スレッド内のすべてのメッセージを取得
messages = client.messages.list(thread_id: thread_id)
puts "\nスレッド内のすべてのメッセージ:"
messages["data"].each do |msg|
  role = msg["role"]
  content = msg["content"].map { |c| c["text"]["value"] }.join("\n")
  puts "#{role.upcase}: #{content}"
end
```

### Responseオブジェクトの活用

Responseオブジェクトは、APIレスポンスを操作するためのいくつかの便利なメソッドを提供します：

```ruby
require 'gemini'

client = Gemini::Client.new(ENV['GEMINI_API_KEY'])

response = client.generate_content(
  "Rubyプログラミング言語について教えてください",
  model: "gemini-2.0-flash-lite"
)

# 基本的なレスポンス情報
puts "有効なレスポンス？ #{response.valid?}"
puts "成功？ #{response.success?}"

# テキストコンテンツへのアクセス
puts "テキスト: #{response.text}"
puts "整形されたテキスト: #{response.formatted_text}"

# 個々のテキストパーツを取得
puts "テキストパーツ数: #{response.text_parts.size}"
response.text_parts.each_with_index do |part, i|
  puts "パート#{i+1}: #{part[0..30]}..." # 各パートの冒頭を表示
end

# 最初の候補へのアクセス
puts "最初の候補の役割: #{response.role}"

# トークン使用情報
puts "プロンプトトークン: #{response.prompt_tokens}"
puts "完了トークン: #{response.completion_tokens}"
puts "総トークン: #{response.total_tokens}"

# 安全情報
puts "終了理由: #{response.finish_reason}"
puts "安全上の理由でブロック？ #{response.safety_blocked?}"

# JSON処理メソッド（構造化出力用）
puts "JSONレスポンス？ #{response.json?}"
if response.json?
  puts "JSONデータ: #{response.json.inspect}"
  puts "整形されたJSON: #{response.to_formatted_json(pretty: true)}"
end

# 高度なニーズのための生データへのアクセス
puts "生レスポンスデータ利用可能？ #{!response.raw_data.nil?}"
```

### 設定

カスタムオプションでクライアントを設定します：

```ruby
require 'gemini'

# グローバル設定
Gemini.configure do |config|
  config.api_key = ENV['GEMINI_API_KEY']
  config.uri_base = "https://generativelanguage.googleapis.com/v1beta"
  config.request_timeout = 60
  config.log_errors = true
end

# またはクライアントごとの設定
client = Gemini::Client.new(
  ENV['GEMINI_API_KEY'],
  {
    uri_base: "https://generativelanguage.googleapis.com/v1beta",
    request_timeout: 60,
    log_errors: true
  }
)

# カスタムヘッダーの追加
client.add_headers({"X-Custom-Header" => "value"})
```

## デモアプリケーション

このgemには、機能を紹介するいくつかのデモアプリケーションが含まれています：

- `demo/demo_ja.rb` - 基本的なテキスト生成とチャット
- `demo/stream_demo_ja.rb` - ストリーミングテキスト生成
- `demo/audio_demo_ja.rb` - 音声文字起こし
- `demo/vision_demo_ja.rb` - 画像認識
- `demo/image_generation_demo_ja.rb` - 画像生成
- `demo/file_vision_demo_ja.rb` - 大きな画像ファイルによる画像認識
- `demo/file_audio_demo_ja.rb` - 大きな音声ファイルによる音声文字起こし
- `demo/structured_output_demo_ja.rb` - スキーマによる構造化JSON出力
- `demo/enum_response_demo_ja.rb` - 列挙型で制約されたレスポンス
- `demo/document_chat_demo.rb` - ドキュメント処理
- `demo/document_conversation_demo.rb` - ドキュメントとの会話
- `demo/document_cache_demo.rb` - ドキュメントキャッシュ

デモは以下のように実行できます：

各デモファイル名に_jaを追加すると、デモの日本語版が起動します。
例：`ruby demo_ja.rb`

```bash
# 基本的なチャットデモ
ruby demo/demo_ja.rb

# ストリーミングチャットデモ
ruby demo/stream_demo_ja.rb

# 音声文字起こし
ruby demo/audio_demo_ja.rb path/to/audio/file.mp3

# 20MB以上の音声ファイルによる音声文字起こし
ruby demo/file_audio_demo_ja.rb path/to/audio/file.mp3

# 画像認識
ruby demo/vision_demo_ja.rb path/to/image/file.jpg

# 大きな画像ファイルによる画像認識
ruby demo/file_vision_demo_ja.rb path/to/image/file.jpg

# 画像生成
ruby demo/image_generation_demo_ja.rb

# JSONスキーマによる構造化出力
ruby demo/structured_output_demo_ja.rb

# 列挙型で制約されたレスポンス
ruby demo/enum_response_demo_ja.rb

# ドキュメント処理
ruby demo/document_chat_demo.rb path/to/document.pdf

# ドキュメントとの会話
ruby demo/document_conversation_demo.rb path/to/document.pdf

# ドキュメントのキャッシュと質問
ruby demo/document_cache_demo.rb path/to/document.pdf
```

## モデル

このライブラリは、様々なGeminiモデルをサポートしています：

- `gemini-2.0-flash-lite`
- `gemini-2.0-flash`
- `gemini-2.0-pro`
- `gemini-1.5-flash`

## 要件

- Ruby 3.0以上
- Faraday 2.0以上
- Google Gemini APIキー

## 貢献

1. フォークする
2. 機能ブランチを作成する（`git checkout -b my-new-feature`）
3. 変更をコミットする（`git commit -am 'Add some feature'`）
4. ブランチにプッシュする（`git push origin my-new-feature`）
5. 新しいPull Requestを作成する

## ライセンス

このgemは[MITライセンス](https://opensource.org/licenses/MIT)の条件の下でオープンソースとして利用可能です。