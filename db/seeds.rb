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
  "Savings",       # deposits into piggy banks (expense)
  "Others"         # filler/misc to balance budgets
]
categories = TITLES.index_with { |t| user.categories.create!(title: t) }

def add_txn!(user:, categories:, title:, description:, amount:, date:, type: nil, saving: nil)
  type ||= (title == "Income" ? "income" : "expense")
  Transaction.create!(
    user: user,
    category: categories.fetch(title),
    description: description,
    amount: amount,
    date: date,
    transaction_type: type,
    saving: saving
  )
end

# ---------- Helpers ----------
def month_first(d) = Date.new(d.year, d.month, 1)
def month_last(d)  = (month_first(d).next_month - 1)
def weekdays(range) = range.select { |d| (1..5).include?(d.wday) }
def weekends(range) = range.select { |d| d.saturday? || d.sunday? }
def randi(r) = r.is_a?(Range) ? rand(r).to_i : r

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

# ---------- Savings goals (pre-existing piggy banks) ----------
puts "Creating savings goals…"
savings_goals = [
  { title: "Emergency Fund", goal: 1_000_000 },
  { title: "Travel Fund",    goal:   300_000 },
  { title: "New Laptop",     goal:   150_000 }
]
piggy_banks = savings_goals.map { |attrs| user.savings.create!(attrs) }

# ---------- Bill schedule (typical JP-ish amounts) ----------
BILLS = {
  "Rent"          => { amount: 80_000,         due: 1  },
  "Electric bill" => { amount: 5_500..9_000,   due: 12 },
  "Gas bill"      => { amount: 3_000..6_000,   due: 15 },
  "Water bill"    => { amount: 2_200..3_800,   due: 20 },
  "Mobile plan"   => { amount: 3_500..5_000,   due: 8  },
  "Home internet" => { amount: 4_800..6_200,   due: 10 },
  "Streaming sub" => { amount: 900..1_500,     due: 5  }
}

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

  # ---- Savings deposits: **round numbers only** (¥10k/¥15k/¥20k/¥25k) into EACH piggy bank, monthly ----
  deposits_day = [[m_first + rand(2..6), m_last].min] # between the 3rd–7th; clamp
  savings_total = 0
  round_choices = [10_000, 15_000, 20_000, 25_000]
  piggy_banks.each do |saving|
    date = deposits_day.first
    amt  = round_choices.sample
    savings_total += amt
    add_txn!(user: user, categories: categories, title: "Savings",
             description: "Saving deposit", amount: amt, date: date, saving: saving)
  end

  # ---- Coffee: Starbucks each weekday (¥540) ----
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
  splits = Array.new(grocery_days.size, grocery_total_planned / grocery_days.size)
  splits.map!.with_index { |base, _i| (base * (0.9 + rand * 0.2)).round(-2) }
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

  # ---- Shopping: very occasional clothes (once across whole window), plus small items ----
  shopping_total = 0
  if !clothes_done_for_window && rand < 0.4
    d = month_days.sample
    amt = 3_000
    shopping_total += amt
    clothes_done_for_window = true
    add_txn!(user: user, categories: categories, title: "Shopping",
             description: "Clothes", amount: amt, date: d)
  end
  month_days.sample(rand(2..4)).sort.each do |d|
    amt = rand(500..2_000)
    shopping_total += amt
    add_txn!(user: user, categories: categories, title: "Shopping",
             description: ["Stationery", "Home goods", "Gift"].sample,
             amount: amt, date: d)
  end

  # ---- Balance the month so not much left (include savings_total) ----
  fixed_and_planned = fixed_total + savings_total + coffee_total + grocery_total + eatout_total + health_total + ent_total + shopping_total
  target_leftover = [0, 5_000, 10_000, 15_000, 20_000].sample
  target_spend = salary_amt - target_leftover

  if target_spend > fixed_and_planned
    top_up = target_spend - fixed_and_planned
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
    overshoot = fixed_and_planned - target_spend
    if overshoot > 0
      refund = [overshoot, rand(1_000..5_000)].min.round(-2)
      add_txn!(user: user, categories: categories, title: "Income",
               description: ["Refund", "Cashback"].sample,
               amount: refund, date: [m_first + 20, m_last].min, type: "income")
    end
  end
end

# ---------- Seed a short, realistic chat history (3 messages each) ----------
# Tip: created_at order matters since your UI orders by created_at.
puts "Creating a short chat history…"
now = Time.zone.now

# 1) User asks to log a coffee
Message.create!(
  user: user, role: "user",
  content: "Can you log a coffee I bought at Starbucks today for 540 yen?",
  created_at: now - 10.minutes, updated_at: now - 10.minutes
)
Message.create!(
  user: user, role: "assistant",
  content: <<~AI.strip,
    Sure — I can prepare a draft.

    ```DRAFT_TX
    {"description":"Starbucks coffee","amount":540,"transaction_type":"expense","date":"#{Date.current}","category_title":"Food"}
    ```
    Confirm to save?
  AI
  created_at: now - 9.minutes, updated_at: now - 9.minutes
)

# 2) User asks for last month's coffee spend
Message.create!(
  user: user, role: "user",
  content: "How much did I spend on coffee last month?",
  created_at: now - 8.minutes, updated_at: now - 8.minutes
)
Message.create!(
  user: user, role: "assistant",
  content: "- You averaged one Starbucks coffee per weekday.\n- Estimated total last month: around 11,000–13,000 yen.\n- Tip: brewing at home 2 days/week could save ~4,000 yen/month.",
  created_at: now - 7.minutes, updated_at: now - 7.minutes
)

# 3) User requests a savings deposit
deposit_day = Date.current.change(day: [5, Date.current.day].min) # early month; clamp to today if earlier
Message.create!(
  user: user, role: "user",
  content: "Add a savings deposit of 15,000 yen to my Travel Fund for this month.",
  created_at: now - 6.minutes, updated_at: now - 6.minutes
)
Message.create!(
  user: user, role: "assistant",
  content: <<~AI.strip,
    Got it — here’s a draft deposit into your piggy bank.

    ```DRAFT_TX
    {"description":"Saving deposit","amount":15000,"transaction_type":"expense","date":"#{deposit_day}","category_title":"Savings"}
    ```
    Confirm to save?
  AI
  created_at: now - 5.minutes, updated_at: now - 5.minutes
)

puts "Done! 🌱 Realistic last-3+ months, round-number piggy-bank deposits, and a seeded chat history."
