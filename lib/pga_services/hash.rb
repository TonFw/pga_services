# Override ruby Hash Obj
class Hash
  # Attr to be external accessible
  attr_accessor :get_url_params

  # Convert string keys to symbol keys
  def it_keys_to_sym
    self.keys.each do |key|
      self[key].it_keys_to_sym if self[key].is_a?(Hash)
      self[(key.to_sym rescue key) || key] = self.delete(key)
    end

    return self
  end
end