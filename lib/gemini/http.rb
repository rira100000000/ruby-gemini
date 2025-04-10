require_relative "http_headers"

module Gemini
  module HTTP
    include HTTPHeaders

    def get(path:, parameters: nil)
      # Gemini API requires API key as a parameter
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
      # Check if there are streaming parameters
      stream_proc = parameters[:stream] if parameters[:stream].respond_to?(:call)
      
      # Determine if we're in streaming mode
      is_streaming = !stream_proc.nil?
      
      # For SSE streaming, add alt=sse to query parameters
      if is_streaming
        query_parameters = query_parameters.merge(alt: 'sse')
      end
      
      # In Gemini API, API key is passed as a query parameter
      query_params = query_parameters.merge(key: @api_key)
      
      # Streaming mode
      if is_streaming
        handle_streaming_request(path, parameters, query_params, stream_proc)
      else
        # Normal batch response mode
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

    private
    
    # Process streaming request
    def handle_streaming_request(path, parameters, query_params, stream_proc)
      # Create a copy of request parameters
      req_parameters = parameters.dup
      
      # Remove the streaming procedure (it would fail JSON serialization)
      req_parameters.delete(:stream)
      
      # Variable to accumulate response for SSE streaming
      accumulated_json = nil
      
      # Execute Faraday request
      connection = conn
      
      begin
        response = connection.post(uri(path: path)) do |req|
          req.headers = headers
          req.params = query_params
          req.body = req_parameters.to_json
          
          # Callback to process SSE streaming events
          req.options.on_data = proc do |chunk, _bytes, env|
            if env && env.status != 200
              raise_error = Faraday::Response::RaiseError.new
              raise_error.on_complete(env.merge(body: try_parse_json(chunk)))
            end
            
            # Process SSE format lines
            process_sse_chunk(chunk, stream_proc) do |parsed_json|
              # Save the first valid JSON
              accumulated_json ||= parsed_json
            end
          end
        end
        
        # Return the complete response
        return accumulated_json || {}
      rescue => e
        log_streaming_error(e) if @log_errors
        raise e
      end
    end
    
    # Process SSE chunk
    def process_sse_chunk(chunk, user_proc)
      # Split chunk into lines
      chunk.each_line do |line|
        # Only process lines that start with "data:"
        if line.start_with?("data:")
          # Remove "data:" prefix
          data = line[5..-1].strip
          
          # Check for end marker
          next if data == "[DONE]"
          
          begin
            # Parse JSON
            parsed_json = JSON.parse(data)
            
            # Pass parsed JSON to user procedure
            user_proc.call(parsed_json)
            
            # Pass to caller
            yield parsed_json if block_given?
          rescue JSON::ParserError => e
            log_json_error(e, data) if @log_errors
          end
        end
      end
    end
    
    # Log streaming error
    def log_streaming_error(error)
      STDERR.puts "[Gemini::HTTP] Streaming error: #{error.message}"
      STDERR.puts error.backtrace.join("\n") if ENV["DEBUG"]
    end
    
    # Log JSON parsing error
    def log_json_error(error, data)
      STDERR.puts "[Gemini::HTTP] JSON parsing error: #{error.message}, data: #{data[0..100]}..." if ENV["DEBUG"]
    end

    def parse_json(response)
      return unless response
      return response unless response.is_a?(String)

      original_response = response.dup
      if response.include?("}\n{")
        # Convert multi-line JSON objects to JSON array
        response = response.gsub("}\n{", "},{").prepend("[").concat("]")
      end

      JSON.parse(response)
    rescue JSON::ParserError
      original_response
    end

    # Generate procedure to handle streaming response
    def to_json_stream(user_proc:)
      proc do |chunk, _bytes, env|
        if env && env.status != 200
          raise_error = Faraday::Response::RaiseError.new
          raise_error.on_complete(env.merge(body: try_parse_json(chunk)))
        end

        # Process according to Gemini API streaming response format
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
        next value unless value.respond_to?(:close) # File or IO object

        # Get file path if available
        path = value.respond_to?(:path) ? value.path : nil
        # Pass empty string for MIME type
        Faraday::UploadIO.new(value, "", path)
      end
    end

    def configure_json_post_request(req, parameters)
      req_parameters = parameters.dup

      if parameters[:stream].respond_to?(:call)
        req.options.on_data = to_json_stream(user_proc: parameters[:stream])
        req_parameters[:stream] = true # Instruct Gemini API to stream
      elsif parameters[:stream]
        raise ArgumentError, "stream parameter must be a Proc or have a #call method"
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