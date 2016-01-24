module PBR
  class Download
    HEAD = {
      'Accept-Language' => 'en-us,en;q=0.5',
      'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      "referer"         => "/",
      'User-Agent'      => "Mozilla/5.0 (Linux; Android 4.3; Nexus 7 Build/JSS15Q) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2307.2 Safari/537.36",
    } # it rocks ^.^
  
    def self.mock u, *o
      o[0] ||= {}
      
      raise "ArgumentError: expect Hash as param 2" unless o[0].is_a?(Hash)
    
      o = o[0]    
    
      h = headers_after_redirects(u)
    
      {
        :destination => "#{o[:dest_dir] || "." }/#{o[:dest_filename] || get_suggested_filename(u)}",
        :size        => h['content-length'].to_i,
        :uri         => h['location'] || u
      }
    end
    
    def self.uri_after_redirects(uri)
      h = HttpRequest.new.head(uri, HEAD)
    
      case h.code
      when 200
        return uri
      when 302
        uri = h.headers['location']
        uri_after_redirects(uri)
      else
        raise "RequestError"         
      end    
    end
    
    def self.headers_after_redirects(uri)
      h = HttpRequest.new.head(uri, HEAD)
    
      case h.code
      when 200
        return h.headers
      when 302
        uri = h.headers['location']
        headers_after_redirects(uri)
      else
        raise "RequestError"         
      end    
    end
    
    def self.get_suggested_filename(uri)
      parser = HTTP::Parser.new()
      uri = parser.parse_url(uri)
      File.basename(uri.path)
    end  
  
    attr_reader :size, :transfered, :code, :status, :uri
    
    def initialize u = nil, *o, &b
      m = self.class.mock u,*o
      
      @uri  = m[:uri]      
      @out  = m[:destination]
      @size = m[:size]
            
      @on_finish_cb = b
      
      @transfered = 0
      @status     = :initialized
      @code       = 0
    end
    
    def destination
      @out
    end
    
    def percent
      transfered.to_f / size
    end
    
    def start
      raise "DownloadNotInitializedError: download not initialized" unless status == :initialized
      
      @status = :started
      
      File.open(@out, "w") do |f|
        HttpRequest.new.get(@uri, nil, HEAD) do |chunk|
          f.write chunk
          @transfered += chunk.size
          @on_progress_changed_cb.call(self) if @on_progress_changed_cb
        end
      end
        
      @status = :completed
      @on_finish_cb.call(self) if @on_finish_cb
    rescue => e
      @code = -1
      @status = :error
    end
    
    # Set a callback for progress changed
    def on_progress &b
      @on_progress_changed_cb = b
    end
    
    # set the finished callback
    def on_finish &b
      @on_finish_cb = b
    end
  end
end
