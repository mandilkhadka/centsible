# db/seeds.rb
require "faker"
require "date"

# If your app config doesn’t set it, uncomment for local dev:
# Time.zone = "Asia/Tokyo"

puts "Cleaning up…"
Transaction.delete_all
Saving.delete_all if defined?(Saving)
Category.delete_all
Message.delete_all if defined?(Message)
User.delete_all

puts "Creating user…"
user = User.create!(
  name: "Test User",
  email: "test@test.com",
  password: "123123",
  starting_balance: 750_000
)

# ---------- Categories ----------
TITLES = [
  "Income",
  "Food",          # groceries, coffee, eating out
  "Utilities",     # rent, bills
  "Entertainment", # movies, karaoke, etc.
  "Shopping",      # clothes & small non-grocery purchases
  "Health",        # pharmacy, clinic
  "Others"         # filler/misc to balance budgets
]
categories = TITLES.index_with { |t| user.categories.create!(title: t) }

def add_txn!(user:, categories:, title:, description:, amount:, date:, type: nil)
  type ||= (title == "Income" ? "income" : "expense")
  Transaction.create!(
    user: user,
    category: categories.fetch(title),
    description: description,
    amount: amount,
    date: date,
    transaction_type: type
  )
end

# ---------- Helpers ----------
def month_first(d) = Date.new(d.year, d.month, 1)
def month_last(d)  = (month_first(d).next_month - 1)
def weekdays(range)
  range.select { |d| (1..5).include?(d.wday) }
end
def weekends(range)
  range.select { |d| d.saturday? || d.sunday? }
end

# deterministic randomness (stable across the same day / SEED)
today = Date.current
seed = (ENV["SEED"] || today.strftime("%Y%m%d")).to_i
srand(seed)
Faker::Config.random = Random.new(seed)

# ---------- Date window: May 1 → today ----------
start_date = Date.new(today.year, 5, 1)
raise "This seed expects start in current year" unless start_date.year == today.year
months = []
d = start_date
while d <= today
  m_first = Date.new(d.year, d.month, 1)
  m_last  = [month_last(m_first), today].min
  months << (m_first..m_last)
  d = m_first.next_month
end

# ---------- Bill schedule (typical JP-ish amounts) ----------
BILLS = {
  "Rent"          => { amount: 80_000, due: 1 },    # keep your earlier rent level
  "Electric bill" => { amount: 5_500..9_000, due: 12 },
  "Gas bill"      => { amount: 3_000..6_000, due: 15 },
  "Water bill"    => { amount: 2_200..3_800, due: 20 },
  "Mobile plan"   => { amount: 3_500..5_000, due: 8 },
  "Home internet" => { amount: 4_800..6_200, due: 10 },
  "Streaming sub" => { amount: 900..1_500, due: 5 }
}

def randi(r) = r.is_a?(Range) ? rand(r).to_i : r

# We’ll allow a single clothes purchase across the whole range (rare).
clothes_done_for_window = false

puts "Creating realistic transactions from #{start_date} to #{today}…"

months.each do |range|
  m_first = range.first
  m_last  = range.last
  month_days = (m_first..m_last).to_a

  # ---- Income (1st of month) ----
  salary_day = Date.new(m_first.year, m_first.month, 1)
  salary_amt = rand(350_000..400_000)
  add_txn!(user: user, categories: categories, title: "Income",
           description: "Monthly salary", amount: salary_amt, date: salary_day, type: "income")

  # ---- Fixed bills (post only if due date <= month end) ----
  fixed_total = 0
  BILLS.each do |desc, cfg|
    due = [cfg[:due], month_last(m_first).day].min
    date = Date.new(m_first.year, m_first.month, due)
    next if date > m_last
    amt = randi(cfg[:amount])
    fixed_total += amt
    add_txn!(user: user, categories: categories, title: "Utilities",
             description: desc, amount: amt, date: date)
  end

  # ---- Coffee: Starbucks on each weekday (¥540) ----
  coffee_days = weekdays(month_days)
  coffee_days.each do |d|
    add_txn!(user: user, categories: categories, title: "Food",
             description: "Starbucks coffee", amount: 540, date: d)
  end
  coffee_total = coffee_days.size * 540

  # ---- Groceries: 4–5 times/mo, realistic totals ----
  grocery_weeks = month_days.group_by(&:cweek).values
  grocery_visits_target = [4, 5].sample
  grocery_days = grocery_weeks.flat_map { |w| w.sample(1) }.first(grocery_visits_target).sort
  grocery_total_planned = rand(38_000..55_000)
  # Split into visits with mild variation
  splits = Array.new(grocery_days.size, grocery_total_planned / grocery_days.size)
  # add some jitter
  splits.map!.with_index { |base, i| (base * (0.9 + rand * 0.2)).round(-2) }
  # normalize
  diff = grocery_total_planned - splits.sum
  splits[0] += diff
  grocery_total = 0
  grocery_days.each_with_index do |d, i|
    amt = [splits[i], 1_200].max
    grocery_total += amt
    add_txn!(user: user, categories: categories, title: "Food",
             description: ["Supermarket", "Discount grocery", "Bulk store"].sample,
             amount: amt, date: d)
  end

  # ---- Eating out: 3–6 weekend meals (¥900–2,400) ----
  eatout_days = weekends(month_days).sample(rand(3..6)).sort
  eatout_total = 0
  eatout_days.each do |d|
    amt = rand(900..2_400)
    eatout_total += amt
    add_txn!(user: user, categories: categories, title: "Food",
             description: ["Ramen", "Izakaya", "Sushi train", "Curry", "Bento"].sample,
             amount: amt, date: d)
  end

  # ---- Health: 1–2 small pharmacy runs (¥900–3,000) ----
  health_days = month_days.sample(rand(1..2)).sort
  health_total = 0
  health_days.each do |d|
    amt = rand(900..3_000)
    health_total += amt
    add_txn!(user: user, categories: categories, title: "Health",
             description: ["Pharmacy", "Vitamins"].sample,
             amount: amt, date: d)
  end

  # ---- Entertainment: 2–4 items (¥700–3,000), occasional 1 bigger (¥5,000–10,000) ----
  ent_days = month_days.sample(rand(2..4)).sort
  ent_total = 0
  ent_days.each do |d|
    amt = rand(700..3_000)
    ent_total += amt
    add_txn!(user: user, categories: categories, title: "Entertainment",
             description: ["Cinema", "Karaoke", "Arcade", "Museum"].sample,
             amount: amt, date: d)
  end
  if rand < 0.35 && m_last >= m_first + 10
    d = (m_first+5..m_last-2).to_a.sample
    big = rand(5_000..10_000)
    ent_total += big
    add_txn!(user: user, categories: categories, title: "Entertainment",
             description: ["Concert ticket", "Theme park day"].sample,
             amount: big, date: d)
  end

  # ---- Shopping: very occasional clothes (once in the whole period), or small household items ----
  shopping_total = 0
  if !clothes_done_for_window && rand < 0.4 # ~40% chance it happens in one of the months
    # Buy clothes exactly once across the whole window
    d = month_days.sample
    amt = 3_000 # you asked ≈ ¥3,000
    shopping_total += amt
    clothes_done_for_window = true
    add_txn!(user: user, categories: categories, title: "Shopping",
             description: "Clothes", amount: amt, date: d)
  end
  # add small non-grocery items (2–4×, ¥500–2,000)
  month_days.sample(rand(2..4)).sort.each do |d|
    amt = rand(500..2_000)
    shopping_total += amt
    add_txn!(user: user, categories: categories, title: "Shopping",
             description: ["Stationery", "Home goods", "Gift"].sample,
             amount: amt, date: d)
  end

  # ---- Balance the month so not much left ----
  fixed_and_planned = fixed_total + coffee_total + grocery_total + eatout_total + health_total + ent_total + shopping_total
  # Target leftover small (¥0–¥20,000). Choose per month to feel natural.
  target_leftover = [0, 5_000, 10_000, 15_000, 20_000].sample
  target_spend = salary_amt - target_leftover

  if target_spend > fixed_and_planned
    top_up = target_spend - fixed_and_planned
    # split top-up into 1–2 realistic "Others" charges near month end (fees, supplies, untracked)
    parts = if top_up > 10_000
              [ (top_up * 0.55).round(-2), (top_up * 0.45).round(-2) ]
            else
              [ top_up.round(-2) ]
            end
    days = [m_last - 1, m_last - 3, m_last - 5].select { |d| d >= m_first }.sample(parts.size)
    parts.each_with_index do |amt, i|
      add_txn!(user: user, categories: categories, title: "Others",
               description: ["Miscellaneous & fees", "Cash top-up & small stuff"].sample,
               amount: [amt, 500].max, date: days[i] || m_last)
    end
  else
    # If over-spent slightly, add a tiny refund to keep small leftover feeling
    overshoot = fixed_and_planned - target_spend
    if overshoot > 0
      refund = [overshoot, rand(1_000..5_000)].min.round(-2)
      add_txn!(user: user, categories: categories, title: "Income",
               description: ["Refund", "Cashback"].sample,
               amount: refund, date: [m_first + 20, m_last].min, type: "income")
    end
  end
end

puts "Done! 🌱 Realistic last-3+ months (May → today), salary on 1st, bills, weekday Starbucks ¥540, \
controlled variance, and end-of-month balancing so savings stay low."
