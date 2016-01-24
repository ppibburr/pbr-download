module PBR
  class Download
    class RequestError < StandardError
      attr_reader :code
      def initialize(msg="Unknown Error", code=-1)
        @code = code
        super(msg)
      end
    end
     
    class WriteError < StandardError
      def initialize(msg="Unknown Error")
        super(msg)
      end    
    end
    
    class NotInitializedError < StandardError
      def initialize(msg="Download#start called but Download#status == EMPTY")
        super(msg)
      end    
    end    
    
    HEAD = {
      'Accept-Language' => 'en-us,en;q=0.5',
      'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      "referer"         => "/",
      'User-Agent'      => "Mozilla/5.0 (Linux; Android 4.3; Nexus 7 Build/JSS15Q) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2307.2 Safari/537.36",
    } # it rocks ^.^
  
    EMPTY       = -1
    INITIALIZED = 0
    STARTED     = 1
    COMPLETE    = 2 
    ERROR       = 3 
    
    MAX_REDIRECTS = 20  
    
    def self.unique_filename uri, *o
      h = mock uri,*o
      f = h[:destination]
      i = 0
        
      while File.exist? f
        t = h[:destination].split(".")
        ext = t.pop
          
        f = t.join(".")
        f += "-#{i}"
        f += ".#{ext}"

        i += 1
      end
      
      File.basename f 
    end
    
    def self.mock u, *o
      o[0] ||= {}
      
      raise "ArgumentError: expect Hash as param 2" unless o[0].is_a?(Hash)
    
      o = o[0]    
    
      h = headers_after_redirects(u)
    
      {
        :size        => (h['content-length'] ||= 0).to_i,
        :uri         => (u = h['location'] || u),
        :destination => "#{o[:dest_dir] || "." }/#{o[:dest_filename] || get_suggested_filename(u, h)}"        
      }
    end
    
    def self.uri_after_redirects(uri, n_rd = 0)
      if n_rd > MAX_REDIRECTS
        raise "RequestError: Returned code - #{310}" 
      end
    
      h = HttpRequest.new.head(uri, HEAD)
    
      case h.code
      when 200
        return uri
      when 302 || 301
        uri = h.headers['location']
        uri_after_redirects(uri, n_rd+1)
      else
        raise RequestError.new("Respone returned: #{h.code}", h.code)            
      end    
    end
    
    def self.headers_after_redirects(uri, n_rd = 0)
      if n_rd > MAX_REDIRECTS
        code = 310
        raise RequestError.new("#{code} Too many redirects. max <= #{MAX_REDIRECTS}", code)  
      end
      
      h = HttpRequest.new.head(uri, HEAD)
    
      case h.code
      when 200
        return h.headers
      when 301
        uri = h.headers['location']
        headers_after_redirects(uri, n_rd+1)
      when 302
        uri = h.headers['location']
        headers_after_redirects(uri)
      else
        raise RequestError.new("Respone returned: #{h.code}", h.code)       
      end    
    end
    
    def self.get_suggested_filename(uri, headers = nil)
      if !headers
        headers = headers_after_redirects(uri)
      end
      
      cd = headers["content-disposition"]
      
      if cd and  cd.index "attachment; filename"
        return cd.split("=").last.strip[1..-2]
      end
      
      parser = HTTP::Parser.new()
      uri = parser.parse_url(uri)

      File.basename(uri.path ? (uri.path == "/" ? "index.html" : uri.path) : "index.html")
    end  
  
    attr_reader :size, :transfered, :code, :status, :uri
    
    def initialize u = nil, *o, &b
      @status = EMPTY
      m = self.class.mock u,*o
      
      @uri  = m[:uri]      
      @out  = m[:destination]
      @size = m[:size]
            
      @on_finish_cb = b
      
      @transfered = 0
      @status     = INITIALIZED
      @code       = 0
    end
    
    def destination
      @out
    end
    
    def percent
      transfered.to_f / size
    end
    
    def start
      raise NotInitializedError.new() unless status == INITIALIZED
      
      @status = STARTED
      
      File.open(@out, "w") do |f|
        HttpRequest.new.get(@uri, nil, HEAD) do |chunk|
          f.write chunk
          @transfered += chunk.size
          begin
            @on_progress_changed_cb.call(self) if @on_progress_changed_cb
          rescue => e
            puts "WARN: on_progress - #{e}"
          end
        end
      end
        
      @status = COMPLETE
      
      begin
        @on_finish_cb.call(self) if @on_finish_cb
      rescue => e
        puts "WARN: on_finish - #{e}"
      end      
    rescue => e
      @status = ERROR
      raise WriteError.new(e.inspect)
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
