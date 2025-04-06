module Gemini
  class Runs
    def initialize(client:)
      @client = client
      @runs = {}
    end

    # 実行の作成
    def create(thread_id:, parameters: {})
      # スレッドが存在するか確認
      begin
        @client.threads.retrieve(id: thread_id)
      rescue => e
        raise Error.new("Thread not found", "thread_not_found")
      end
      
      # メッセージを取得してGemini形式に変換
      messages_response = @client.messages.list(thread_id: thread_id)
      messages = messages_response["data"]
      
      # Gemini API用のcontents配列を構築
      contents = messages.map do |msg|
        {
          "role" => msg["role"],
          "parts" => msg["content"].map do |content|
            { "text" => content["text"]["value"] }
          end
        }
      end
      
      # モデルを取得（パラメータまたはスレッドのデフォルト）
      model = parameters[:model] || @client.threads.get_model(id: thread_id)
      
      # Gemini APIリクエスト
      api_params = {
        contents: contents,
        model: model
      }.merge(parameters.reject { |k, _| [:assistant_id, :instructions].include?(k) })
      
      response = @client.chat(parameters: api_params)
      
      # 応答をモデルメッセージとして追加
      if response["candidates"] && !response["candidates"].empty?
        candidate = response["candidates"][0]
        content = candidate["content"]
        
        if content && content["parts"] && !content["parts"].empty?
          model_text = content["parts"][0]["text"]
          
          @client.messages.create(
            thread_id: thread_id,
            parameters: {
              role: "model",
              content: model_text
            }
          )
        end
      end
      
      # 実行情報を作成
      run_id = SecureRandom.uuid
      created_at = Time.now.to_i
      
      run = {
        "id" => run_id,
        "object" => "thread.run",
        "created_at" => created_at,
        "thread_id" => thread_id,
        "status" => "completed",
        "model" => model,
        "metadata" => parameters[:metadata] || {},
        "response" => response
      }
      
      @runs[run_id] = run
      
      # 返却用に応答から非公開情報を削除
      run_response = run.dup
      run_response.delete("response")
      run_response
    end

    # 実行情報の取得
    def retrieve(thread_id:, id:)
      run = @runs[id]
      raise Error.new("Run not found", "run_not_found") unless run
      raise Error.new("Run does not belong to thread", "invalid_thread_run") unless run["thread_id"] == thread_id
      
      # 返却用に応答から非公開情報を削除
      run_response = run.dup
      run_response.delete("response")
      run_response
    end

    # 実行のキャンセル（未実装の機能だが、インターフェース互換性のため）
    def cancel(thread_id:, id:)
      run = retrieve(thread_id: thread_id, id: id)
      
      # Geminiでは実際にはキャンセル機能はないが、インターフェースを提供
      # すでに完了している実行なのでキャンセル不可のエラーを返す
      raise Error.new("Run is already completed", "run_already_completed") if run["status"] == "completed"
      
      run
    end
  end
end