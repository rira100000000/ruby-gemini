module Gemini
  class Threads
    def initialize(client:)
      @client = client
      @threads = {}
    end

    # Retrieve a thread
    def retrieve(id:)
      thread = @threads[id]
      raise Error.new("Thread not found", "thread_not_found") unless thread
      
      {
        "id" => thread[:id],
        "object" => "thread",
        "created_at" => thread[:created_at],
        "metadata" => thread[:metadata]
      }
    end

    # Create a new thread
    def create(parameters: {})
      thread_id = SecureRandom.uuid
      created_at = Time.now.to_i
      
      @threads[thread_id] = {
        id: thread_id,
        created_at: created_at,
        metadata: parameters[:metadata] || {},
        model: parameters[:model] || "gemini-2.0-flash-lite"
      }
      
      {
        "id" => thread_id,
        "object" => "thread",
        "created_at" => created_at,
        "metadata" => @threads[thread_id][:metadata]
      }
    end

    # Modify a thread
    def modify(id:, parameters: {})
      thread = @threads[id]
      raise Error.new("Thread not found", "thread_not_found") unless thread
      
      # Apply modifiable parameters
      thread[:metadata] = parameters[:metadata] if parameters[:metadata]
      thread[:model] = parameters[:model] if parameters[:model]
      
      {
        "id" => thread[:id],
        "object" => "thread",
        "created_at" => thread[:created_at],
        "metadata" => thread[:metadata]
      }
    end

    # Delete a thread
    def delete(id:)
      raise Error.new("Thread not found", "thread_not_found") unless @threads[id]
      @threads.delete(id)
      
      { "id" => id, "object" => "thread.deleted", "deleted" => true }
    end

    # Internal use: Get thread model
    def get_model(id:)
      thread = @threads[id]
      raise Error.new("Thread not found", "thread_not_found") unless thread
      
      thread[:model]
    end
  end
end