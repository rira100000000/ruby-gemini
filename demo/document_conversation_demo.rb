require 'bundler/setup'
require 'gemini'
require 'logger'
require 'readline'
require 'securerandom'

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

# Get API key from environment variable
api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")

begin
  logger.info "Initializing Gemini client..."
  client = Gemini::Client.new(api_key)
  
  puts "Gemini Document Conversation Demo"
  puts "==================================="
  
  # Specify document file path
  document_path = ARGV[0] || raise("Usage: ruby document_conversation_demo_en.rb <document_file_path>")
  
  # Check if file exists
  unless File.exist?(document_path)
    raise "File not found: #{document_path}"
  end
  
  # Display file information
  file_size = File.size(document_path) / 1024.0 # Size in KB
  file_extension = File.extname(document_path)
  puts "File: #{File.basename(document_path)}"
  puts "Size: #{file_size.round(2)} KB"
  puts "Type: #{file_extension}"
  puts "==================================="
  
  puts "Processing document..."
  model = "gemini-1.5-flash"
  
  # Upload file
  file = File.open(document_path, "rb")
  begin
    upload_result = client.files.upload(file: file)
    file_uri = upload_result["file"]["uri"]
    file_name = upload_result["file"]["name"]
    
    # Determine MIME type (simple detection from extension)
    mime_type = case file_extension.downcase
                when ".pdf"
                  "application/pdf"
                when ".txt"
                  "text/plain"
                when ".html", ".htm"
                  "text/html"
                when ".css"
                  "text/css"
                when ".md"
                  "text/md"
                when ".csv"
                  "text/csv"
                when ".xml"
                  "text/xml"
                when ".rtf"
                  "text/rtf"
                when ".js"
                  "application/x-javascript"
                when ".py"
                  "application/x-python"
                else
                  "application/octet-stream"
                end
  ensure
    file.close
  end
  
  puts "File has been uploaded: #{file_name}"
  
  # Conversation history
  conversation_history = []
  
  # Add first message (document)
  conversation_history << {
    role: "user",
    parts: [
      { file_data: { mime_type: mime_type, file_uri: file_uri } }
    ]
  }
  
  # Add first question
  first_question = "Please give a brief description of this document."
  conversation_history << {
    role: "user",
    parts: [{ text: first_question }]
  }
  
  puts "First question: #{first_question}"
  
  # Send to Gemini API
  response = client.chat(parameters: {
    model: model,
    contents: conversation_history
  })
  
  if response.success?
    # Add response to log
    conversation_history << {
      role: "model",
      parts: [{ text: response.text }]
    }
    
    # Display response
    puts "\n[Model]: #{response.text}"
  else
    raise "Failed to generate initial response: #{response.error || 'Unknown error'}"
  end
  
  # Command completion settings
  COMMANDS = ['exit', 'history', 'help'].freeze
  Readline.completion_proc = proc { |input|
    COMMANDS.grep(/^#{Regexp.escape(input)}/)
  }
  
  puts "\nYou can ask questions about the document. Commands: exit, history, help"
  
  # Conversation loop
  loop do
    # User input
    user_input = Readline.readline("\n> ", true)
    
    # If input is nil (Ctrl+D)
    break if user_input.nil?
    
    user_input = user_input.strip
    
    # Command processing
    case user_input.downcase
    when 'exit'
      puts "Ending conversation."
      break
      
    when 'history'
      puts "\n=== Conversation History ==="
      conversation_history.each do |msg|
        role = msg[:role]
        if msg[:parts].first.key?(:file_data)
          puts "[#{role}]: [DOCUMENT]"
        else
          content_text = msg[:parts].map { |part| part[:text] }.join("\n")
          puts "[#{role}]: #{content_text}"
        end
        puts "--------------------------"
      end
      next
      
    when 'help'
      puts "\nCommands:"
      puts "  exit    - End conversation"
      puts "  history - Display conversation history"
      puts "  help    - Display this help"
      puts "  other   - Ask questions about the document"
      next
      
    when ''
      # Skip empty input
      next
    end
    
    # Add user's question to conversation history
    conversation_history << {
      role: "user",
      parts: [{ text: user_input }]
    }
    
    # Send to Gemini API
    begin
      # Display processing message
      puts "Processing..."
      
      response = client.chat(parameters: {
        model: model,
        contents: conversation_history
      })
      
      if response.success?
        # Add response to log
        conversation_history << {
          role: "model",
          parts: [{ text: response.text }]
        }
        
        # Display response
        puts "\n[Model]: #{response.text}"
      else
        puts "Error: #{response.error || 'Unknown error'}"
      end
    rescue => e
      puts "An error occurred: #{e.message}"
    end
  end

rescue StandardError => e
  logger.error "An error occurred: #{e.message}"
  logger.error e.backtrace.join("\n") if ENV["DEBUG"]
end