categories = ["foods", "enertainment"]
categories.each do |category|
  Category.create(title: category, limit: 1000, user: User.first)
end
