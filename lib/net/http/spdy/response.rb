class Net::HTTPResponse
  if RUBY_VERSION < '2.0.0'
    attr_reader :uri

    def uri= uri # :nodoc:
      @uri = uri.dup if uri
    end
  end

  attr_reader :associated_responses

  ##
  # Returns true when itself has a associated_response
  def has_associated_response?
    @associated_responses ||= []
    not @associated_responses.empty?
  end

  ##
  # Returns associated responses
  def associated_responses
    @associated_responses ||= []
    return @associated_responses
  end
end
