module Gemini
  class Runs
    def initialize(client:)
      @client = client
      @runs = {}
    end

    # Create a run (with streaming callback support)
    def create(thread_id:, parameters: {}, &stream_callback)
      # Check if thread exists
      begin
        @client.threads.retrieve(id: thread_id)
      rescue => e
        raise Error.new("Thread not found", "thread_not_found")
      end
      
      # Get messages and convert to Gemini format
      messages_response = @client.messages.list(thread_id: thread_id)
      messages = messages_response["data"]
      
      # Extract system prompt
      system_instruction = parameters[:system_instruction]
      
      # Build contents array for Gemini API
      contents = messages.map do |msg|
        {
          "role" => msg["role"],
          "parts" => msg["content"].map do |content|
            { "text" => content["text"]["value"] }
          end
        }
      end
      
      # Get model
      model = parameters[:model] || @client.threads.get_model(id: thread_id)
      
      # Prepare parameters for Gemini API request
      api_params = {
        contents: contents,
        model: model
      }
      
      # Add system instruction if provided
      if system_instruction
        api_params[:system_instruction] = {
          parts: [
            { text: system_instruction.is_a?(String) ? system_instruction : system_instruction.to_s }
          ]
        }
      end
      
      # Add other parameters (update exclusion list)
      api_params.merge!(parameters.reject { |k, _| [:assistant_id, :instructions, :system_instruction, :model].include?(k) })
  

      # Create run info in advance
      run_id = SecureRandom.uuid
      created_at = Time.now.to_i
      
      run = {
        "id" => run_id,
        "object" => "thread.run",
        "created_at" => created_at,
        "thread_id" => thread_id,
        "status" => "running",
        "model" => model,
        "metadata" => parameters[:metadata] || {},
        "response" => nil
      }
      
      # Temporarily store run info
      @runs[run_id] = run
      
      # If streaming callback is provided
      if block_given?
        # Variable to accumulate complete response text
        response_text = ""
        
        # API request with streaming mode
        response = @client.chat(parameters: api_params) do |chunk_text, raw_chunk|
          # Call user-provided callback
          stream_callback.call(chunk_text) if stream_callback
          
          # Accumulate complete response text
          response_text += chunk_text
        end
        
        # After streaming completion, save as message
        if !response_text.empty?
          @client.messages.create(
            thread_id: thread_id,
            parameters: {
              role: "model",
              content: response_text
            }
          )
        end
        
        # Update run info
        run["status"] = "completed"
        run["response"] = response
      else
        # Traditional batch response mode
        response = @client.chat(parameters: api_params)
        
        # Add response as model message
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
        
        # Update run info
        run["status"] = "completed"
        run["response"] = response
      end
      
      # Remove private information for response
      run_response = run.dup
      run_response.delete("response")
      run_response
    end

    # Retrieve run information
    def retrieve(thread_id:, id:)
      run = @runs[id]
      raise Error.new("Run not found", "run_not_found") unless run
      raise Error.new("Run does not belong to thread", "invalid_thread_run") unless run["thread_id"] == thread_id
      
      # Remove private information for response
      run_response = run.dup
      run_response.delete("response")
      run_response
    end

    # Cancel a run (unimplemented feature, but provided for interface compatibility)
    def cancel(thread_id:, id:)
      run = retrieve(thread_id: thread_id, id: id)
      
      # Gemini has no actual cancel function, but provide interface
      # Return error for already completed runs
      raise Error.new("Run is already completed", "run_already_completed") if run["status"] == "completed"
      
      run
    end
  end
end