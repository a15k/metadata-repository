class SearchResults
  attr_reader :items, :count

  def initialize(items, count)
    @items = items
    @count = count
  end

  def ==(other)
    other.is_a?(self.class) && items == other.items && count == other.count
  end
end
