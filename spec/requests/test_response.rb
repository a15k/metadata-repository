class ActionDispatch::TestResponse
  def body_hash
    @body_hash ||= JSON.parse(body, symbolize_names: true)
  end

  def errors
    body_hash[:errors]
  end
end
