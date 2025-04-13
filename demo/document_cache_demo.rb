#!/usr/bin/env ruby
require 'bundler/setup'
require 'gemini'
require 'json'
require 'faraday'
require 'base64'
require 'readline'
require 'fileutils'
require 'time'

# Get API key from environment variable
api_key = ENV['GEMINI_API_KEY'] || raise("Please set the GEMINI_API_KEY environment variable")

# File to save cache information
cache_info_file = "gemini_cache_info.json"

# Mode selection: Create new cache or use existing cache
cache_mode = :create
cache_name = nil
model = "gemini-1.5-flash-001" # Default model

if File.exist?(cache_info_file) && !ENV['FORCE_NEW_CACHE']
  begin
    # Load cache information
    cache_info = JSON.parse(File.read(cache_info_file))
    cache_name = cache_info["cache_name"]
    document_name = cache_info["document_name"]
    
    puts "Found existing cache information:"
    puts "  Cache name: #{cache_name}"
    puts "  Document: #{document_name}"
    
    # Verify cache validity
    begin
      conn = Faraday.new do |f|
        f.options[:timeout] = 30
      end
      
      response = conn.get("https://generativelanguage.googleapis.com/v1beta/#{cache_name}") do |req|
        req.params['key'] = api_key
      end
      
      if response.status == 200
        cache_data = JSON.parse(response.body)
        if cache_data["expireTime"]
          expire_time = Time.parse(cache_data["expireTime"])
          current_time = Time.now
          
          puts "  Expiration: #{expire_time.strftime('%Y-%m-%d %H:%M:%S')}"
          puts "  Current time: #{current_time.strftime('%Y-%m-%d %H:%M:%S')}"
          
          if current_time < expire_time
            puts "Cache is valid. Starting in reuse mode."
            cache_mode = :reuse
            # Get model information
            model = cache_data["model"].sub("models/", "") if cache_data["model"]
            puts "  Model: #{model}"
          else
            puts "Cache has expired. Starting in creation mode."
          end
        else
          puts "Failed to verify cache information. Starting in creation mode."
        end
      else
        puts "Error occurred while checking cache (Status: #{response.status})"
        puts "Starting in creation mode."
      end
    rescue => e
      puts "Error occurred while checking cache: #{e.message}"
      puts "Starting in creation mode."
    end
  rescue => e
    puts "Failed to load cache information: #{e.message}"
    puts "Starting in creation mode."
  end
else
  puts "Cache information not found or force new cache mode enabled."
  puts "Starting in creation mode."
end

puts "==================================="

# For new cache creation mode
if cache_mode == :create
  # Specify document file path
  file_path = ARGV[0] || raise("Usage: ruby document_cache_demo_en.rb <document_file_path>")
  
  # Check if file exists
  unless File.exist?(file_path)
    raise "File not found: #{file_path}"
  end
  
  # Display file information
  file_size = File.size(file_path) / 1024.0 # Size in KB
  file_extension = File.extname(file_path)
  document_name = File.basename(file_path)
  puts "File: #{document_name}"
  puts "Size: #{file_size.round(2)} KB"
  puts "Type: #{file_extension}"
  puts "==================================="
  
  # Start time
  start_time = Time.now
  
  # Determine MIME type
  mime_type = case file_extension.downcase
              when '.pdf'
                'application/pdf'
              when '.txt'
                'text/plain'
              when '.html', '.htm'
                'text/html'
              when '.csv'
                'text/csv'
              when '.md'
                'text/md'
              when '.js'
                'application/x-javascript'
              when '.py'
                'application/x-python'
              else
                'application/octet-stream'
              end
  
  puts "Saving document to cache..."
  puts "MIME type: #{mime_type}"
  
  # Warning for large files
  if file_size > 10000 # More than 10MB
    puts "Warning: File size is large, processing may take some time."
    puts "Please be patient during processing..."
  end

  # Display progress indicator for monitoring large file processing
  progress_thread = Thread.new do
    spinner = ['|', '/', '-', '\\']
    i = 0
    loop do
      print "\rProcessing... #{spinner[i]} "
      i = (i + 1) % 4
      sleep 0.5
    end
  end
  
  begin
    # Read file and encode in Base64
    file_data = File.binread(file_path)
    encoded_data = Base64.strict_encode64(file_data)
    
    # Prepare cache request
    request = {
      "model" => "models/#{model}",
      "contents" => [
        {
          "parts" => [
            {
              "inline_data" => {
                "mime_type" => mime_type,
                "data" => encoded_data
              }
            }
          ],
          "role" => "user"
        }
      ],
      "systemInstruction" => {
        "parts" => [
          {
            "text" => "You are a document analysis expert. Please accurately understand the content of the given document and answer questions in detail."
          }
        ],
        "role" => "system"
      },
      "ttl" => "86400s" # 24 hours
    }
    
    # Create Faraday instance (extended timeout)
    conn = Faraday.new do |f|
      f.options[:timeout] = 300 # 5 minute timeout
    end
    
    # Send API request
    response = conn.post("https://generativelanguage.googleapis.com/v1beta/cachedContents") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.params['key'] = api_key
      req.body = JSON.generate(request)
    end
    
    # End progress thread
    progress_thread.kill
    print "\r" # Return cursor to beginning of line
    
    if response.status == 200
      result = JSON.parse(response.body)
      cache_name = result["name"]
      
      # Save cache information to JSON (for reuse)
      cache_info = {
        "cache_name" => cache_name,
        "document_name" => document_name,
        "created_at" => Time.now.to_s,
        "file_path" => file_path,
        "model" => model
      }
      
      File.write(cache_info_file, JSON.pretty_generate(cache_info))
      
      # End time and elapsed time calculation
      end_time = Time.now
      elapsed_time = end_time - start_time
      
      puts "Success! Document has been saved to cache."
      puts "Cache name: #{cache_name}"
      puts "Processing time: #{elapsed_time.round(2)} seconds"
      
      # Token usage information (if available)
      if result["usageMetadata"] && result["usageMetadata"]["totalTokenCount"]
        token_count = result["usageMetadata"]["totalTokenCount"]
        puts "Token usage: #{token_count}"
        
        if token_count < 32768
          puts "Warning: Token count is below the minimum requirement (32,768). Cache may not function properly."
        else
          puts "Token count meets the minimum requirement (32,768)."
        end
      end
    else
      puts "Error: Failed to create cache (Status code: #{response.status})"
      if response.body
        begin
          error_json = JSON.parse(response.body)
          puts JSON.pretty_generate(error_json)
        rescue
          puts response.body
        end
      end
      exit 1
    end
  rescue => e
    # End progress thread
    progress_thread.kill if progress_thread.alive?
    print "\r" # Return cursor to beginning of line
    puts "An error occurred: #{e.message}"
    exit 1
  end
else
  # For reuse mode, use the cache information loaded
  puts "Reusing existing cache: #{cache_name}"
  puts "Model being used: #{model}"
end

puts "==================================="

# Command completion settings
COMMANDS = ['exit', 'list', 'delete', 'help', 'info', 'extend'].freeze
Readline.completion_proc = proc { |input|
  COMMANDS.grep(/^#{Regexp.escape(input)}/)
}

puts "\nYou can ask questions about the cached document."
puts "Commands: exit, list (list caches), delete (delete cache), info (information), extend (extend expiration), help"

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
    puts "Exiting demo."
    break
    
  when 'list'
    puts "\n=== Cache List ==="
    conn = Faraday.new
    response = conn.get("https://generativelanguage.googleapis.com/v1beta/cachedContents") do |req|
      req.params['key'] = api_key
    end
    
    if response.status == 200
      result = JSON.parse(response.body)
      if result["cachedContents"] && !result["cachedContents"].empty?
        result["cachedContents"].each do |cache|
          puts "Name: #{cache['name']}"
          puts "Model: #{cache['model']}"
          puts "Created: #{Time.parse(cache['createTime']).strftime('%Y-%m-%d %H:%M:%S')}" if cache['createTime']
          puts "Expires: #{Time.parse(cache['expireTime']).strftime('%Y-%m-%d %H:%M:%S')}" if cache['expireTime']
          puts "Tokens: #{cache.dig('usageMetadata', 'totalTokenCount') || 'unknown'}"
          puts "--------------------------"
        end
      else
        puts "No caches found."
      end
    else
      puts "Failed to retrieve cache list (Status code: #{response.status})"
    end
    next
    
  when 'delete'
    puts "\nDeleting cache: #{cache_name}"
    conn = Faraday.new
    response = conn.delete("https://generativelanguage.googleapis.com/v1beta/#{cache_name}") do |req|
      req.params['key'] = api_key
    end
    
    if response.status == 200
      puts "Cache has been deleted."
      # Also delete cache information file
      FileUtils.rm(cache_info_file) if File.exist?(cache_info_file)
      puts "Cache information file has also been deleted."
      puts "Exiting demo."
      break
    else
      puts "Failed to delete cache (Status code: #{response.status})"
    end
    next
    
  when 'info'
    puts "\n=== Current Cache Information ==="
    conn = Faraday.new
    response = conn.get("https://generativelanguage.googleapis.com/v1beta/#{cache_name}") do |req|
      req.params['key'] = api_key
    end
    
    if response.status == 200
      cache_data = JSON.parse(response.body)
      puts "Cache name: #{cache_data['name']}"
      puts "Model: #{cache_data['model']}"
      
      if cache_data["createTime"]
        create_time = Time.parse(cache_data["createTime"])
        puts "Created: #{create_time.strftime('%Y-%m-%d %H:%M:%S')}"
      end
      
      if cache_data["expireTime"]
        expire_time = Time.parse(cache_data["expireTime"])
        current_time = Time.now
        remaining_time = expire_time - current_time
        puts "Expires: #{expire_time.strftime('%Y-%m-%d %H:%M:%S')}"
        
        # Display remaining time in days, hours, minutes, seconds
        days = (remaining_time / 86400).to_i
        hours = ((remaining_time % 86400) / 3600).to_i
        minutes = ((remaining_time % 3600) / 60).to_i
        seconds = (remaining_time % 60).to_i
        
        puts "Time remaining: #{days} days #{hours} hours #{minutes} minutes #{seconds} seconds"
      end
      
      if cache_data.dig("usageMetadata", "totalTokenCount")
        token_count = cache_data['usageMetadata']['totalTokenCount']
        puts "Token count: #{token_count}"
        
        if token_count < 32768
          puts "Warning: Token count is below the minimum requirement (32,768)."
        else
          puts "Token count meets the minimum requirement (32,768)."
        end
      end
    else
      puts "Failed to retrieve cache information (Status code: #{response.status})"
    end
    next
    
  when 'extend'
    puts "\nExtending cache expiration: #{cache_name}"
    conn = Faraday.new
    response = conn.patch("https://generativelanguage.googleapis.com/v1beta/#{cache_name}") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.params['key'] = api_key
      req.params['updateMask'] = 'ttl'
      req.body = JSON.generate({ "ttl" => "86400s" }) # Extend by 24 hours
    end
    
    if response.status == 200
      result = JSON.parse(response.body)
      if result["expireTime"]
        expire_time = Time.parse(result["expireTime"])
        puts "Expiration has been extended to: #{expire_time.strftime('%Y-%m-%d %H:%M:%S')}"
      else
        puts "Expiration extension was successful, but couldn't retrieve the new expiration time."
      end
    else
      puts "Failed to extend expiration (Status code: #{response.status})"
    end
    next
    
  when 'help'
    puts "\nCommands:"
    puts "  exit   - Exit the demo"
    puts "  list   - Display list of caches"
    puts "  delete - Delete current cache"
    puts "  info   - Show detailed information about current cache"
    puts "  extend - Extend cache expiration by 24 hours"
    puts "  help   - Display this help"
    puts "  other  - Ask questions about the document"
    next
    
  when ''
    # Skip empty input
    next
  end
  
  # Process question
  begin
    # Start measuring processing time
    query_start_time = Time.now
    
    # Display processing message
    puts "Processing..."
    
    # Prepare question request
    request = {
      "contents" => [
        {
          "parts" => [
            { "text" => user_input }
          ],
          "role" => "user"
        }
      ],
      "cachedContent" => cache_name
    }
    
    # Send API request
    conn = Faraday.new do |f|
      f.options[:timeout] = 60
    end
    
    response = conn.post("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.params['key'] = api_key
      req.body = JSON.generate(request)
    end
    
    # End measuring processing time
    query_end_time = Time.now
    query_time = query_end_time - query_start_time
    
    if response.status == 200
      result = JSON.parse(response.body)
      
      # Extract text response
      answer_text = nil
      if result["candidates"] && !result["candidates"].empty?
        candidate = result["candidates"][0]
        if candidate["content"] && candidate["content"]["parts"]
          parts = candidate["content"]["parts"]
          texts = parts.map { |part| part["text"] }.compact
          answer_text = texts.join("\n")
        end
      end
      
      if answer_text
        puts "\nAnswer:"
        puts answer_text
        puts "\nProcessing time: #{query_time.round(2)} seconds"
        
        # Token usage information (if available)
        if result["usage"]
          puts "Token usage:"
          puts "  Prompt: #{result['usage']['promptTokens'] || 'N/A'}"
          puts "  Generation: #{result['usage']['candidateTokens'] || 'N/A'}"
          puts "  Total: #{result['usage']['totalTokens'] || 'N/A'}"
        end
      else
        puts "Error: Could not extract text from response"
        puts "Response content:"
        puts JSON.pretty_generate(result)
      end
    else
      puts "Error: Failed to process question (Status code: #{response.status})"
      if response.body
        begin
          error_json = JSON.parse(response.body)
          puts JSON.pretty_generate(error_json)
        rescue
          puts response.body
        end
      end
    end
  rescue => e
    puts "An error occurred while processing the question: #{e.message}"
  end
end