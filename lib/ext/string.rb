class String
  # Fake out "force_encoding" if we're on 1.8
  #
  def force_encoding enc
    self
  end unless method_defined? :force_encoding
end