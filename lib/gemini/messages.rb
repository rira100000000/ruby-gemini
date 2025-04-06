module Gemini
  class Messages
    def initialize(client:)
      @client = client
      @message_store = {} # スレッドIDごとのメッセージを保存
    end

    # スレッド内のメッセージをリスト
    def list(thread_id:, parameters: {})
      # 内部実装：メッセージストアからスレッドのメッセージを取得
      messages = get_thread_messages(thread_id)
      
      # OpenAIと同様のレスポンス形式
      {
        "object" => "list",
        "data" => messages,
        "first_id" => messages.first&.dig("id"),
        "last_id" => messages.last&.dig("id"),
        "has_more" => false
      }
    end

    # 特定のメッセージを取得
    def retrieve(thread_id:, id:)
      messages = get_thread_messages(thread_id)
      message = messages.find { |m| m["id"] == id }
      
      raise Error.new("Message not found", "message_not_found") unless message
      message
    end

    # 新しいメッセージを作成
    def create(thread_id:, parameters: {})
      # スレッドが存在するか確認（存在しない場合は例外発生）
      validate_thread_exists(thread_id)
      
      message_id = SecureRandom.uuid
      created_at = Time.now.to_i
      
      # パラメータからメッセージデータを構築
      message = {
        "id" => message_id,
        "object" => "thread.message",
        "created_at" => created_at,
        "thread_id" => thread_id,
        "role" => parameters[:role] || "user",
        "content" => format_content(parameters[:content])
      }
      
      # メッセージをスレッドに追加
      add_message_to_thread(thread_id, message)
      
      message
    end

    # メッセージを変更
    def modify(thread_id:, id:, parameters: {})
      message = retrieve(thread_id: thread_id, id: id)
      
      # 変更可能なパラメータを適用
      message["metadata"] = parameters[:metadata] if parameters[:metadata]
      
      message
    end

    # メッセージを削除（論理削除）
    def delete(thread_id:, id:)
      message = retrieve(thread_id: thread_id, id: id)
      
      # 論理削除フラグを設定
      message["deleted"] = true
      
      { "id" => id, "object" => "thread.message.deleted", "deleted" => true }
    end

    private

    # スレッドのメッセージを取得（内部メソッド）
    def get_thread_messages(thread_id)
      validate_thread_exists(thread_id)
      @message_store[thread_id] ||= []
      @message_store[thread_id].reject { |m| m["deleted"] }
    end

    # スレッドにメッセージを追加（内部メソッド）
    def add_message_to_thread(thread_id, message)
      @message_store[thread_id] ||= []
      @message_store[thread_id] << message
      message
    end

    # スレッドの存在を確認（内部メソッド）
    def validate_thread_exists(thread_id)
      begin
        @client.threads.retrieve(id: thread_id)
      rescue => e
        raise Error.new("Thread not found", "thread_not_found")
      end
    end

    # コンテンツをGemini API形式に変換（内部メソッド）
    def format_content(content)
      case content
      when String
        [{ "type" => "text", "text" => { "value" => content } }]
      when Array
        content.map do |item|
          if item.is_a?(String)
            { "type" => "text", "text" => { "value" => item } }
          else
            item
          end
        end
      when Hash
        [content]
      else
        [{ "type" => "text", "text" => { "value" => content.to_s } }]
      end
    end
  end

  # エラークラス
  class Error < StandardError
    attr_reader :code
    
    def initialize(message, code = nil)
      super(message)
      @code = code
    end
  end
end