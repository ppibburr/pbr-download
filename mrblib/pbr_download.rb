module PBR
  class Download
    HEAD = {
      'Accept-Language' => 'en-us,en;q=0.5',
      'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      "referer"         => "/",
      'User-Agent'      => "Mozilla/5.0 (Linux; Android 4.3; Nexus 7 Build/JSS15Q) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2307.2 Safari/537.36",
    } # it rocks ^.^
  
  
    attr_reader :size, :transfered, :code, :status
    def initialize u, out, &b
      @uri = u
      @out = out
      @on_finish_cb = b
      @size = 0
      @transfered = 0
  
      @status = :initialized
      
      @code   = 0
    end
    
    def path
      @out
    end
    
    def percent
      transfered.to_f / size
    end
    
    def completed?
      status == :completed
    end
    
    def start
      h     = HttpRequest.new.head(@uri, HEAD)
    
      case h.code
      when 200
        @size = h.headers['content-length'].to_i
      
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
      when 302
        @uri = h.headers['location']
        start
      else
        @status = :error
        @code = h.code
        
        @on_finish_cb.call(self) if @on_finish_cb            
      end
    rescue => e
      @code = -1
      @status = :error
    end
    
    def on_progress &b
      @on_progress_changed_cb = b
    end
    
    def on_finish &b
      @on_finish_cb = b
    end
  end
end
