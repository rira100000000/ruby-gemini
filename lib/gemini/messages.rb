module Gemini
  class Messages
    def initialize(client:)
      @client = client
      @message_store = {} # Store messages by thread ID
    end

    # List messages in a thread
    def list(thread_id:, parameters: {})
      # Internal implementation: Get messages for the thread from message store
      messages = get_thread_messages(thread_id)
      
      # OpenAI-like response format
      {
        "object" => "list",
        "data" => messages,
        "first_id" => messages.first&.dig("id"),
        "last_id" => messages.last&.dig("id"),
        "has_more" => false
      }
    end

    # Retrieve a specific message
    def retrieve(thread_id:, id:)
      messages = get_thread_messages(thread_id)
      message = messages.find { |m| m["id"] == id }
      
      raise Error.new("Message not found", "message_not_found") unless message
      message
    end

    # Create a new message
    def create(thread_id:, parameters: {})
      # Check if thread exists (raise exception if not)
      validate_thread_exists(thread_id)
      
      message_id = SecureRandom.uuid
      created_at = Time.now.to_i
      
      # Build message data from parameters
      message = {
        "id" => message_id,
        "object" => "thread.message",
        "created_at" => created_at,
        "thread_id" => thread_id,
        "role" => parameters[:role] || "user",
        "content" => format_content(parameters[:content])
      }
      
      # Add message to thread
      add_message_to_thread(thread_id, message)
      
      message
    end

    # Modify a message
    def modify(thread_id:, id:, parameters: {})
      message = retrieve(thread_id: thread_id, id: id)
      
      # Apply modifiable parameters
      message["metadata"] = parameters[:metadata] if parameters[:metadata]
      
      message
    end

    # Delete a message (logical deletion)
    def delete(thread_id:, id:)
      message = retrieve(thread_id: thread_id, id: id)
      
      # Set logical deletion flag
      message["deleted"] = true
      
      { "id" => id, "object" => "thread.message.deleted", "deleted" => true }
    end

    private

    # Get thread messages (internal method)
    def get_thread_messages(thread_id)
      validate_thread_exists(thread_id)
      @message_store[thread_id] ||= []
      @message_store[thread_id].reject { |m| m["deleted"] }
    end

    # Add message to thread (internal method)
    def add_message_to_thread(thread_id, message)
      @message_store[thread_id] ||= []
      @message_store[thread_id] << message
      message
    end

    # Validate thread exists (internal method)
    def validate_thread_exists(thread_id)
      begin
        @client.threads.retrieve(id: thread_id)
      rescue => e
        raise Error.new("Thread not found", "thread_not_found")
      end
    end

    # Convert content to Gemini API format (internal method)
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

  # Error class
  class Error < StandardError
    attr_reader :code
    
    def initialize(message, code = nil)
      super(message)
      @code = code
    end
  end
end