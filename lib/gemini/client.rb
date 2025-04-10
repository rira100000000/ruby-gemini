module Gemini
  class Client
    include Gemini::HTTP
    
    SENSITIVE_ATTRIBUTES = %i[@api_key @extra_headers].freeze
    CONFIG_KEYS = %i[api_key uri_base extra_headers log_errors request_timeout].freeze
    
    attr_reader(*CONFIG_KEYS, :faraday_middleware)
    attr_writer :api_key
    
    def initialize(api_key = nil, config = {}, &faraday_middleware)
      # Handle API key passed directly as argument
      config[:api_key] = api_key if api_key
      
      CONFIG_KEYS.each do |key|
        # Set instance variables. Use global config if no setting provided
        instance_variable_set(
          "@#{key}",
          config[key].nil? ? Gemini.configuration.send(key) : config[key]
        )
      end
      
      @api_key ||= ENV["GEMINI_API_KEY"]
      @faraday_middleware = faraday_middleware
      
      raise ConfigurationError, "API key is not set" unless @api_key
    end
    
    # Thread management accessor
    def threads
      @threads ||= Gemini::Threads.new(client: self)
    end
    
    # Message management accessor
    def messages
      @messages ||= Gemini::Messages.new(client: self)
    end
    
    # Run management accessor
    def runs
      @runs ||= Gemini::Runs.new(client: self)
    end

    def audio
      @audio ||= Gemini::Audio.new(client: self)
    end

    def files
      @files ||= Gemini::Files.new(client: self)
    end

    def reset_headers
      @extra_headers = {}
    end
    
    # Access to conn (Faraday connection) for Audio features
    # Wrapper to allow using private methods from HTTP module externally
    def conn(multipart: false)
      super(multipart: multipart)
    end
    
    # OpenAI chat-like text generation method for Gemini API
    # Extended to support streaming callbacks
    def chat(parameters: {}, &stream_callback)
      model = parameters.delete(:model) || "gemini-2.0-flash-lite"
      
      # If streaming callback is provided
      if block_given?
        path = "models/#{model}:streamGenerateContent"
        # Set up stream callback
        stream_params = parameters.dup
        stream_params[:stream] = proc { |chunk| process_stream_chunk(chunk, &stream_callback) }
        return json_post(path: path, parameters: stream_params)
      else
        # Normal batch response mode
        path = "models/#{model}:generateContent"
        return json_post(path: path, parameters: parameters)
      end
    end
    
    # Method corresponding to OpenAI's embeddings
    def embeddings(parameters: {})
      model = parameters.delete(:model) || "text-embedding-model"
      path = "models/#{model}:embedContent"
      json_post(path: path, parameters: parameters)
    end
    
    # Method corresponding to OpenAI's completions
    # Uses same endpoint as chat in Gemini API
    def completions(parameters: {}, &stream_callback)
      chat(parameters: parameters, &stream_callback)
    end
    
    # Accessor for sub-clients
    def models
      @models ||= Gemini::Models.new(client: self)
    end
    
    # Helper methods for convenience
    
    # Method with usage similar to OpenAI's chat
    # Supports streaming callbacks
    # Added system_instruction parameter
    def generate_content(prompt, model: "gemini-2.0-flash-lite", system_instruction: nil, **parameters, &stream_callback)
      content = format_content(prompt)
      params = {
        contents: [content],
        model: model
      }
      
      # Add system_instruction if provided
      if system_instruction
        params[:system_instruction] = format_content(system_instruction)
      end
      
      # Merge other parameters
      params.merge!(parameters)
      
      if block_given?
        chat(parameters: params, &stream_callback)
      else
        chat(parameters: params)
      end
    end
    
    # Streaming text generation
    # Provides same functionality as generate_content above, but explicitly for streaming
    # Added system_instruction parameter
    def generate_content_stream(prompt, model: "gemini-2.0-flash-lite", system_instruction: nil, **parameters, &block)
      raise ArgumentError, "Block is required for streaming" unless block_given?
      
      content = format_content(prompt)
      params = {
        contents: [content],
        model: model
      }
      
      # Add system_instruction if provided
      if system_instruction
        params[:system_instruction] = format_content(system_instruction)
      end
      
      # Merge other parameters
      params.merge!(parameters)
      
      chat(parameters: params, &block)
    end

    # Debug inspect method
    def inspect
      vars = instance_variables.map do |var|
        value = instance_variable_get(var)
        SENSITIVE_ATTRIBUTES.include?(var) ? "#{var}=[REDACTED]" : "#{var}=#{value.inspect}"
      end
      "#<#{self.class}:#{object_id} #{vars.join(', ')}>"
    end
    
    private
    
    # Process stream chunk and pass to callback
    def process_stream_chunk(chunk, &callback)
      if chunk.respond_to?(:dig) && chunk.dig("candidates", 0, "content", "parts", 0, "text")
        chunk_text = chunk.dig("candidates", 0, "content", "parts", 0, "text")
        callback.call(chunk_text, chunk)
      elsif chunk.respond_to?(:dig) && chunk.dig("candidates", 0, "content", "parts")
        # Pass empty part to callback if no text
        callback.call("", chunk)
      else
        # Treat other chunk types (metadata, etc.) as empty string
        callback.call("", chunk)
      end
    end
    
    # Convert input to Gemini API format
    def format_content(input)
      case input
      when String
        { parts: [{ text: input }] }
      when Array
        if input.all? { |part| part.is_a?(Hash) && part.key?(:text) }
          { parts: input }
        else
          { parts: input.map { |text| { text: text.to_s } } }
        end
      when Hash
        input
      else
        { parts: [{ text: input.to_s }] }
      end
    end
  end
end