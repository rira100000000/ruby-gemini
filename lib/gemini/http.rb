require_relative "http_headers"

module Gemini
  module HTTP
    include HTTPHeaders

    def get(path:, parameters: nil)
      # Gemini APIはパラメータにAPIキーを必要とする
      params = (parameters || {}).merge(key: @api_key)
      parse_json(conn.get(uri(path: path), params) do |req|
        req.headers = headers
      end&.body)
    end

    def post(path:)
      parse_json(conn.post(uri(path: path)) do |req|
        req.headers = headers
        req.params = { key: @api_key }
      end&.body)
    end

    def json_post(path:, parameters:, query_parameters: {})
      # ストリーミングパラメータがあるかチェック
      stream_proc = parameters[:stream] if parameters[:stream].respond_to?(:call)
      
      # ストリーミングモードかどうかの判定
      is_streaming = !stream_proc.nil?
      
      # SSEストリーミングの場合はクエリパラメータにalt=sseを追加
      if is_streaming
        query_parameters = query_parameters.merge(alt: 'sse')
      end
      
      # Gemini APIではAPIキーをクエリパラメータとして渡す
      query_params = query_parameters.merge(key: @api_key)
      
      # ストリーミングモードの場合
      if is_streaming
        handle_streaming_request(path, parameters, query_params, stream_proc)
      else
        # 通常の一括レスポンスモード
        parse_json(conn.post(uri(path: path)) do |req|
          configure_json_post_request(req, parameters)
          req.params = req.params.merge(query_params)
        end&.body)
      end
    end

    def multipart_post(path:, parameters: nil)
      parse_json(conn(multipart: true).post(uri(path: path)) do |req|
        req.headers = headers.merge({ "Content-Type" => "multipart/form-data" })
        req.params = { key: @api_key }
        req.body = multipart_parameters(parameters)
      end&.body)
    end

    def delete(path:)
      parse_json(conn.delete(uri(path: path)) do |req|
        req.headers = headers
        req.params = { key: @api_key }
      end&.body)
    end
    
    # JSONレスポンスをパースするメソッド
    # @param response [String] パースするJSONレスポンス
    # @return [Hash, Array, String] パースされたJSONオブジェクトまたは元の文字列
    def parse_json(response)
      return unless response
      return response unless response.is_a?(String)

      original_response = response.dup
      if response.include?("}\n{")
        # 複数行のJSONオブジェクトらしきものをJSON配列に変換する
        response = response.gsub("}\n{", "},{").prepend("[").concat("]")
      end

      JSON.parse(response)
    rescue JSON::ParserError
      original_response
    end

    private
    
    # ストリーミングリクエストを処理
    def handle_streaming_request(path, parameters, query_params, stream_proc)
      # リクエストパラメータのコピーを作成
      req_parameters = parameters.dup
      
      # ストリーミングプロシージャを削除（JSONシリアライズに失敗するため）
      req_parameters.delete(:stream)
      
      # SSEストリーミング用に応答を蓄積する変数
      accumulated_json = nil
      
      # Faradayリクエストを実行
      connection = conn
      
      begin
        response = connection.post(uri(path: path)) do |req|
          req.headers = headers
          req.params = query_params
          req.body = req_parameters.to_json
          
          # SSEストリーミングイベントを処理するコールバック
          req.options.on_data = proc do |chunk, _bytes, env|
            if env && env.status != 200
              raise_error = Faraday::Response::RaiseError.new
              raise_error.on_complete(env.merge(body: try_parse_json(chunk)))
            end
            
            # SSEフォーマットの行を処理
            process_sse_chunk(chunk, stream_proc) do |parsed_json|
              # 最初の有効なJSONを保存
              accumulated_json ||= parsed_json
            end
          end
        end
        
        # 全体のレスポンスを返す
        return accumulated_json || {}
      rescue => e
        log_streaming_error(e) if @log_errors
        raise e
      end
    end
    
    # SSEチャンクを処理
    def process_sse_chunk(chunk, user_proc)
      # チャンクを行に分割
      chunk.each_line do |line|
        # "data:"で始まる行だけを処理
        if line.start_with?("data:")
          # "data:"プレフィックスを取り除く
          data = line[5..-1].strip
          
          # 終了マーカーをチェック
          next if data == "[DONE]"
          
          begin
            # JSONをパース
            parsed_json = JSON.parse(data)
            
            # ユーザープロシージャにパースしたJSONを渡す
            user_proc.call(parsed_json)
            
            # 呼び出し元に渡す
            yield parsed_json if block_given?
          rescue JSON::ParserError => e
            log_json_error(e, data) if @log_errors
          end
        end
      end
    end
    
    # ストリーミングエラーをログに記録
    def log_streaming_error(error)
      STDERR.puts "[Gemini::HTTP] ストリーミングエラー: #{error.message}"
      STDERR.puts error.backtrace.join("\n") if ENV["DEBUG"]
    end
    
    # JSON解析エラーをログに記録
    def log_json_error(error, data)
      STDERR.puts "[Gemini::HTTP] JSON解析エラー: #{error.message}, データ: #{data[0..100]}..." if ENV["DEBUG"]
    end
    
    # ストリーミングレスポンスを処理するためのプロシージャを生成
    def to_json_stream(user_proc:)
      proc do |chunk, _bytes, env|
        if env && env.status != 200
          raise_error = Faraday::Response::RaiseError.new
          raise_error.on_complete(env.merge(body: try_parse_json(chunk)))
        end

        # Gemini APIのストリーミングレスポンス形式に合わせた処理
        parsed_chunk = try_parse_json(chunk)
        user_proc.call(parsed_chunk) if parsed_chunk
      end
    end

    def conn(multipart: false)
      connection = Faraday.new do |f|
        f.options[:timeout] = @request_timeout
        f.request(:multipart) if multipart
        f.use Gemini::MiddlewareErrors if @log_errors
        f.response :raise_error
        f.response :json
      end

      @faraday_middleware&.call(connection)

      connection
    end

    def uri(path:)
      File.join(@uri_base, path)
    end

    def multipart_parameters(parameters)
      parameters&.transform_values do |value|
        next value unless value.respond_to?(:close) # FileまたはIOオブジェクト

        # ファイルパスがあれば取得
        path = value.respond_to?(:path) ? value.path : nil
        # MIMEタイプは空文字で渡す
        Faraday::UploadIO.new(value, "", path)
      end
    end

    def configure_json_post_request(req, parameters)
      req_parameters = parameters.dup

      if parameters[:stream].respond_to?(:call)
        req.options.on_data = to_json_stream(user_proc: parameters[:stream])
        req_parameters[:stream] = true # Gemini APIにストリーミングを指示する
      elsif parameters[:stream]
        raise ArgumentError, "stream パラメータは Proc か #call メソッドを持つものである必要があります"
      end

      req.headers = headers
      req.body = req_parameters.to_json
    end

    def try_parse_json(maybe_json)
      JSON.parse(maybe_json)
    rescue JSON::ParserError
      maybe_json
    end
  end
end