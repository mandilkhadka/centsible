require "faker"

puts "Cleaning up…"
Transaction.delete_all
Category.delete_all
Message.delete_all
User.delete_all

puts "Creating user…"
user = User.create!(
  name: "Test",
  email: "test@test.com",
  password: "123123",
  starting_balance: 750_000
)

CATEGORIES = ["Food", "Health", "Commute", "Utilities", "Entertainment", "Others"]

puts "Creating categories…"
categories = CATEGORIES.map do |title|
  user.categories.create!(
    title: title,
    limit: rand(50_000..100_000)
  )
end

puts "Creating transactions…"
# ~50 transactions, spread across categories

DESCRIPTIONS = {
  "Food"          => ["Ramen shop", "Supermarket", "Bento", "Cafe latte", "Sushi train", "Convenience store"],
  "Health"        => ["Pharmacy", "Clinic visit", "Vitamins", "Gym day pass", "Massage"],
  "Commute"       => ["Train fare", "Bus IC top-up", "Taxi", "Bike repair", "Highway toll"],
  "Utilities"     => ["Electric bill", "Water bill", "Gas bill", "Mobile plan", "Home internet"],
  "Entertainment" => ["Cinema", "Arcade", "Concert ticket", "Streaming sub", "Karaoke"],
  "Others"        => ["Stationery", "Gift", "Home goods", "Random purchase", "Household"],
}

TRANSACTION = ['expense', 'income']

20.times do
  category = categories.sample
  title = category.title


  Transaction.create!(
    user: user,
    category: category,
    description: DESCRIPTIONS[title].sample,
    amount: rand(300..8_000),
    date: Faker::Date.between(from: 180.days.ago, to: Date.today),
    transaction_type: category.title == 'Income' ? 'income' : 'expense'
  )
end

puts "Done!"
