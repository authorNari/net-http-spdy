class Net::HTTPResponse
  if RUBY_VERSION < "2.0.0"
    attr_accessor :uri
  end

  attr_reader :associated_responses

  ##
  # Returns true when itself has a associated_response
  def has_associatd_response?
    @associated_responses ||= []
    not @response.empty?
  end

  ##
  # Returns associated responses
  def associated_responses
    @associated_responses ||= []
    return @associated_responses
  end
end
