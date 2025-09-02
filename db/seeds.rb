# db/seeds.rb
require "faker"
require "date"

# If your app config doesn’t set it, uncomment the next line for local dev:
# Time.zone = "Asia/Tokyo"

puts "Cleaning up…"
Transaction.delete_all
Saving.delete_all
Category.delete_all
Message.delete_all
User.delete_all

puts "Creating user…"
user = User.create!(
  name: "Test User",
  email: "test@test.com",
  password: "123123",
  starting_balance: 750_000
)

# --- Categories (add Income so we can mark income cleanly) ---
CATEGORIES = ["Income", "Food", "Health", "Commute", "Utilities", "Entertainment", "Others"]
categories_by_title = CATEGORIES.index_with { |title| user.categories.create!(title: title) }


def add_txn!(user:, categories_by_title:, title:, description:, amount_yen:, date:, type: nil)
  type ||= (title == "Income" ? "income" : "expense")
  Transaction.create!(
    user: user,
    category: categories_by_title.fetch(title),
    description: description,
    amount: amount_yen,
    date: date,
    transaction_type: type
  )
end

# ---- Helpers ----
def month_first(date) = Date.new(date.year, date.month, 1)
def month_last(date)  = (month_first(date).next_month - 1)

def sample_days(range, count, only_weekdays: nil, only_weekends: nil, exclude_days: [])
  pool = range.to_a - exclude_days
  if only_weekdays
    pool.select! { |d| (1..5).include?(d.wday) }
  elsif only_weekends
    pool.select! { |d| d.saturday? || d.sunday? }
  end
  return [] if pool.empty? || count <= 0
  pool.sample([count, pool.size].min).sort
end

def rand_yen(range) = rand(range).to_i

# Use Date.current to honor Rails Time.zone (avoids UTC off-by-one)
today = Date.current
first_of_year = Date.new(today.year, 1, 1)

# Build windows: Jan 1 .. Aug 31 full, plus Sep 1..today partial (we’re on Sep 1 in your case)
windows = []
(1..12).each do |m|
  m_first = Date.new(today.year, m, 1)
  m_last  = month_last(m_first)
  break if m_first > today # stop after current month
  if m < today.month
    windows << (m_first..m_last)   # past months full
  elsif m == today.month
    windows << (m_first..today)    # current month partial
  end
end

# ------- Config -------
salary_day = 25
utility_day = { rent: 1, electric: 12, gas: 15, water: 20, mobile: 8, internet: 10, streaming: 5 }

# Optional: deterministic randomness per day (handy for repeat demos on the same date)
seed = (ENV["SEED"] || today.strftime("%Y%m%d")).to_i
srand(seed)
Faker::Config.random = Random.new(seed)

puts "Creating realistic transactions from Jan 1 to #{today}…"

windows.each do |range|
  month_start = month_first(range.first)
  month_end   = range.last
  is_current_month = (month_start.year == today.year && month_start.month == today.month)

  # Variable spend window:
  # - For current month: use <= yesterday (avoid piling on "today")
  # - For past months: full month
  var_end = is_current_month ? (today - 1) : month_end
  has_past_days = var_end >= month_start
  var_range = has_past_days ? (month_start..var_end) : nil
  exclude_today = is_current_month ? [today] : []

  # ---- INCOME ----
  payday = [Date.new(month_start.year, month_start.month, salary_day), month_end].min
  if !is_current_month || payday <= today
    add_txn!(
      user: user, categories_by_title: categories_by_title, title: "Income",
      description: "Salary", amount_yen: rand_yen(300_000..450_000), date: payday, type: "income"
    )
  end

  # Optional side-income (0–1×), must be <= today in current month
  if rand < 0.4
    side_pool = is_current_month ? (month_start..today) : (month_start..month_end)
    side_date = sample_days(side_pool, 1).first
    if side_date
      add_txn!(
        user: user, categories_by_title: categories_by_title, title: "Income",
        description: ["Freelance work", "Item resell", "Refund"].sample,
        amount_yen: rand_yen(5_000..40_000), date: side_date, type: "income"
      )
    end
  end

  # ---- UTILITIES ---- (bill appears only when due date <= today for current month)
  {
    "Rent"          => [80_000, utility_day[:rent]],
    "Electric bill" => [rand_yen(5_000..12_000), utility_day[:electric]],
    "Gas bill"      => [rand_yen(3_000..7_000),  utility_day[:gas]],
    "Water bill"    => [rand_yen(2_000..4_500),  utility_day[:water]],
    "Mobile plan"   => [rand_yen(2_500..6_000),  utility_day[:mobile]],
    "Home internet" => [rand_yen(4_000..7_000),  utility_day[:internet]],
    "Streaming sub" => [rand_yen(900..2_000),    utility_day[:streaming]]
  }.each do |desc, (amt, due_day)|
    due_date = Date.new(month_start.year, month_start.month, [due_day, month_end.day].min)
    next if is_current_month && due_date > today
    add_txn!(user: user, categories_by_title: categories_by_title,
             title: "Utilities", description: desc, amount_yen: amt, date: due_date)
  end

  # ---- VARIABLE SPEND (past days only) ----
  if has_past_days
    # Commute (~65% of weekdays; 1–2 legs; rare taxi)
    weekday_days = sample_days(var_range, (var_range.last - var_range.first + 1).to_i,
                               only_weekdays: true, exclude_days: exclude_today)
    commute_days = weekday_days.select { rand < 0.65 }
    commute_days.each do |d|
      trips = rand < 0.85 ? 2 : 1
      trips.times do
        add_txn!(user: user, categories_by_title: categories_by_title, title: "Commute",
                 description: ["Train fare", "Bus fare", "IC top-up"].sample,
                 amount_yen: rand_yen(170..420), date: d)
      end
      if rand < 0.04
        add_txn!(user: user, categories_by_title: categories_by_title, title: "Commute",
                 description: "Taxi (late night)", amount_yen: rand_yen(1_200..3_500), date: d)
      end
    end

    # Food — groceries 1–3×/week
    weeks = var_range.group_by(&:cweek).values
    weeks.each do |days|
      times = rand(1..3)
      sample_days((days.first..days.last), times, exclude_days: exclude_today).each do |d|
        add_txn!(user: user, categories_by_title: categories_by_title, title: "Food",
                 description: ["Supermarket", "Discount grocery", "Bulk store"].sample,
                 amount_yen: rand_yen(1_800..6_500), date: d)
      end
    end

    # Food — conbini (8–18/mo, ≤1/day)
    sample_days(var_range, rand(8..18), exclude_days: exclude_today).each do |d|
      add_txn!(user: user, categories_by_title: categories_by_title, title: "Food",
               description: ["Convenience store", "Onigiri & drink", "Snack run"].sample,
               amount_yen: rand_yen(300..900), date: d)
    end

    # Food — coffee (8–22/mo, ≤1/day)
    sample_days(var_range, rand(8..22), exclude_days: exclude_today).each do |d|
      add_txn!(user: user, categories_by_title: categories_by_title, title: "Food",
               description: ["Cafe latte", "Drip coffee", "Iced coffee"].sample,
               amount_yen: rand_yen(350..680), date: d)
    end

    # Food — eating out (weekends 3–8×/mo)
    sample_days(var_range, rand(3..8), only_weekends: true, exclude_days: exclude_today).each do |d|
      add_txn!(user: user, categories_by_title: categories_by_title, title: "Food",
               description: ["Ramen shop", "Sushi train", "Izakaya", "Curry house", "Bento shop"].sample,
               amount_yen: rand_yen(800..2_600), date: d)
    end

    # Health (1–3×/mo)
    sample_days(var_range, rand(1..3), exclude_days: exclude_today).each do |d|
      add_txn!(user: user, categories_by_title: categories_by_title, title: "Health",
               description: ["Pharmacy", "Clinic visit", "Vitamins"].sample,
               amount_yen: rand_yen(900..6_000), date: d)
    end

    # Entertainment (2–6×/mo) + occasional big
    sample_days(var_range, rand(2..6), exclude_days: exclude_today).each do |d|
      add_txn!(user: user, categories_by_title: categories_by_title, title: "Entertainment",
               description: ["Cinema", "Arcade", "Karaoke", "Museum", "Game top-up"].sample,
               amount_yen: rand_yen(700..3_000), date: d)
    end
    if rand < 0.35
      big = sample_days(var_range, 1, exclude_days: exclude_today).first
      if big
        add_txn!(user: user, categories_by_title: categories_by_title, title: "Entertainment",
                 description: ["Concert ticket", "Theme park day"].sample,
                 amount_yen: rand_yen(5_000..12_000), date: big)
      end
    end

    # Others (3–7×/mo)
    sample_days(var_range, rand(3..7), exclude_days: exclude_today).each do |d|
      add_txn!(user: user, categories_by_title: categories_by_title, title: "Others",
               description: ["Stationery", "Home goods", "Gift", "Household"].sample,
               amount_yen: rand_yen(400..6_000), date: d)
    end
  end

  # ---- TODAY: add 0–2 tiny transactions so the current date isn’t empty (demo-friendly) ----
  if is_current_month
    # We already added due-today utilities (e.g., Rent on the 1st). Add at most two small extras.
    smalls = []
    smalls << ["Food", "Convenience store", rand_yen(300..900)] if rand < 0.40
    smalls << ["Food", "Cafe latte",        rand_yen(350..680)] if rand < 0.30
    smalls.first(2).each do |title, desc, amt|
      add_txn!(user: user, categories_by_title: categories_by_title, title: title,
               description: desc, amount_yen: amt, date: today)
    end
  end
end

puts "Done! 🌱 Realistic history with rent; includes minimal same-day activity and honors Time.zone."
