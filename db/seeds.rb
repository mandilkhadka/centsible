# db/seeds.rb
require "faker"
require "date"

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
  starting_balance: 100_000
)

# ---------- Categories ----------
TITLES = [
  "Income",
  "Food",
  "Utilities",
  "Entertainment",
  "Shopping",
  "Health",
  "Savings",  # deposits into piggy banks (expense)
  "Others"
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
def weekdays(days) = days.select { |dt| (1..5).include?(dt.wday) }
def weekends(days) = days.select { |dt| dt.saturday? || dt.sunday? }
def randi(r) = r.is_a?(Range) ? rand(r).to_i : r

# Split a total across n days with light randomness; amounts rounded to ¥100
def split_total_random(total, n, min_per: 1200)
  return [] if n <= 0 || total <= 0
  base = Array.new(n, min_per)
  remaining = total - n * min_per
  if remaining < 0
    base[0] = total
    return base
  end
  weights = Array.new(n) { rand(0.7..1.3) }
  sumw = weights.sum
  amounts = base.each_with_index.map { |b, i| (b + remaining * (weights[i] / sumw)).round(-2) }
  diff = total - amounts.sum
  if diff != 0
    idxs = (0...n).to_a
    idxs.sample(diff.abs).each { |i| amounts[i] += (diff.positive? ? 100 : -100) }
  end
  amounts.map! { |a| [a, min_per].max }
  amounts
end

# Build round-number monthly deposits that sum to a target, bounded by min/max
def build_round_deposit_plan(months_count:, target_total:, min: 10_000, max: 40_000)
  # amounts will be multiples of 5k between 0 and max
  step = 5_000
  target_total = (target_total / step) * step # force multiple of 5k

  # start with zeros so we can keep Savings < Food per month
  amounts = Array.new(months_count, 0)
  remaining = target_total

  # First pass: fill each month up to min (if we can)
  i = 0
  while remaining >= min && i < months_count
    amounts[i] = min
    remaining -= min
    i += 1
  end

  # Distribute remaining in 10k blocks, then 5k, without exceeding max
  months_count.times do |idx|
    while remaining >= 10_000 && (amounts[idx] + 10_000) <= max
      amounts[idx] += 10_000
      remaining -= 10_000
    end
  end
  loop do
    changed = false
    months_count.times do |idx|
      break if remaining < step
      if (amounts[idx] + step) <= max
        amounts[idx] += step
        remaining -= step
        changed = true
      end
    end
    break unless changed
  end

  amounts
end

# deterministic randomness (stable across same day / SEED)
today = Date.current
seed = (ENV["SEED"] || today.strftime("%Y%m%d")).to_i
srand(seed)
Faker::Config.random = Random.new(seed)

# ---------- Date window: Jan 1 → today (gives enough months for the trip plan) ----------
start_date = Date.new(today.year, 1, 1)
raise "This seed expects start in current year" unless start_date.year == today.year

months = []
d = start_date
while d <= today
  m_first = Date.new(d.year, d.month, 1)
  m_last  = [month_last(m_first), today].min
  months << (m_first..m_last)
  d = m_first.next_month
end

# ---------- Savings goals ----------
puts "Creating savings goals…"
TRIP_GOAL_YEN      = 320_000                   # pick a realistic demo goal
TRIP_LEFTOVER_YEN  = 20_000                    # "almost complete" → 20k left
DOWNPAYMENT_GOAL   = 1_000_000                 # adjust if you like

savings_goals = [
  { title: "Down payment for new appartment", goal: DOWNPAYMENT_GOAL },
  { title: "Trip to France (Christmas)",      goal: TRIP_GOAL_YEN }
]
piggy_banks = savings_goals.map { |attrs| user.savings.create!(attrs) }

trip_fr = piggy_banks.find { |s| s.title == "Trip to France (Christmas)" }
raise "Trip saving not found" unless trip_fr

# Plan trip deposits to total (goal - 20,000) over the whole window.
# Cap per-month at 40k so Savings never beats Food (55k).
trip_target_total = TRIP_GOAL_YEN - TRIP_LEFTOVER_YEN # multiple of 5k already
trip_plan = build_round_deposit_plan(
  months_count: months.size,
  target_total: trip_target_total,
  min: 10_000, max: 40_000
)

# ---------- Bill schedule (Utilities) ----------
BILLS = {
  "Rent"          => { amount: 80_000,         due: 1  },
  "Electric bill" => { amount: 5_500..9_000,   due: 12 },
  "Gas bill"      => { amount: 3_000..6_000,   due: 15 },
  "Water bill"    => { amount: 2_200..3_800,   due: 20 },
  "Mobile plan"   => { amount: 3_500..5_000,   due: 8  },
  "Home internet" => { amount: 4_800..6_200,   due: 10 },
  "Streaming sub" => { amount: 900..1_500,     due: 5  }
}

# We’ll allow a single clothes purchase across the whole window (rare).
clothes_done_for_window = false

puts "Creating realistic transactions from #{start_date} to #{today}…"

months.each_with_index do |range, mi|
  m_first = range.first
  m_last  = range.last
  month_days = (m_first..m_last).to_a
  full_month     = (m_last == month_last(m_first))
  days_elapsed   = month_days.size
  days_in_month  = month_last(m_first).day
  salary_day     = Date.new(m_first.year, m_first.month, 1) # insert AFTER expenses

  # ---- Utilities (largest category) ----
  BILLS.each do |desc, cfg|
    due  = [cfg[:due], month_last(m_first).day].min
    date = Date.new(m_first.year, m_first.month, due)
    next if date > m_last
    amt  = randi(cfg[:amount])
    add_txn!(user: user, categories: categories, title: "Utilities",
             description: desc, amount: amt, date: date)
  end

  # ---------------------- FOOD: lock the total ------------------------
  # Target = ¥55,000 for full months; pro-rate for current month
  food_target = if full_month
                  55_000
                else
                  ((55_000 * (days_elapsed.to_f / days_in_month)).round(-2)).to_i
                end

  # Coffee: one per weekday (¥540)
  coffee_days = weekdays(month_days)
  coffee_days.each do |d|
    add_txn!(user: user, categories: categories, title: "Food",
             description: "Starbucks coffee", amount: 540, date: d)
  end
  coffee_total = coffee_days.size * 540

  # Eating out
  weekend_pool = weekends(month_days)
  eatout_count = full_month ? rand(3..6) : [[(6.0 * days_elapsed / days_in_month).round, 1].max, weekend_pool.size].min
  eatout_days = weekend_pool.sample(eatout_count).sort
  eatout_amounts = eatout_days.map { rand(900..2_400) }
  eatout_total = eatout_amounts.sum

  # Ensure groceries remain feasible
  grocery_visits = full_month ? rand(4..5) : [[(5.0 * days_elapsed / days_in_month).ceil, 1].max, 5].min
  min_grocery_total = grocery_visits * 1_200
  while (food_target - coffee_total - eatout_total) < min_grocery_total && eatout_days.any?
    removed = eatout_amounts.pop
    eatout_days.pop
    eatout_total -= removed
  end

  # Groceries split to hit target
  grocery_total = [food_target - coffee_total - eatout_total, min_grocery_total].max
  grocery_days = month_days.group_by(&:cweek).values.map { |w| w.sample(1) }.flatten
  grocery_days = grocery_days.first(grocery_visits).sort
  grocery_amounts = split_total_random(grocery_total, grocery_days.size, min_per: 1_200)

  # Create eating out & groceries txns
  eatout_days.each_with_index do |d, i|
    add_txn!(user: user, categories: categories, title: "Food",
             description: ["Ramen", "Izakaya", "Sushi train", "Curry", "Bento"].sample,
             amount: eatout_amounts[i], date: d)
  end
  grocery_days.each_with_index do |d, i|
    add_txn!(user: user, categories: categories, title: "Food",
             description: ["Supermarket", "Discount grocery", "Bulk store"].sample,
             amount: grocery_amounts[i], date: d)
  end
  # ------------------- end FOOD --------------------------------------

  # ---- Savings deposits ----
  deposits_day = [[m_first + rand(2..6), m_last].min] # between 3rd–7th; clamp
  # Keep total Savings < Food: Trip plan per month (<=40k) + Down payment 5k–10k
  down_payment_amt = [5_000, 10_000].sample

  [*piggy_banks].each do |saving|
    date = deposits_day.first
    amt  = if saving == trip_fr
             trip_plan[mi]
           else
             down_payment_amt
           end
    next if amt.to_i <= 0
    add_txn!(user: user, categories: categories, title: "Savings",
             description: "Saving deposit - #{saving.title}", amount: amt, date: date, saving: saving)
  end

  # ---- Health: 1–2 small pharmacy runs (¥900–3,000) ----
  month_days.sample(rand(1..2)).sort.each do |d|
    add_txn!(user: user, categories: categories, title: "Health",
             description: ["Pharmacy", "Vitamins"].sample,
             amount: rand(900..3_000), date: d)
  end

  # ---- Entertainment: 2–4 items (¥700–3,000), optional bigger (¥5,000–10,000) ----
  ent_days = month_days.sample(rand(2..4)).sort
  ent_days.each do |d|
    add_txn!(user: user, categories: categories, title: "Entertainment",
             description: ["Cinema", "Karaoke", "Arcade", "Museum"].sample,
             amount: rand(700..3_000), date: d)
  end
  if rand < 0.35 && (m_last - m_first) >= 10
    d = (m_first+5..m_last-2).to_a.sample
    add_txn!(user: user, categories: categories, title: "Entertainment",
             description: ["Concert ticket", "Theme park day"].sample,
             amount: rand(5_000..10_000), date: d)
  end

  # ---- Shopping: rare clothes + a few small items ----
  if !clothes_done_for_window && rand < 0.4
    d = month_days.sample
    add_txn!(user: user, categories: categories, title: "Shopping",
             description: "Clothes", amount: 3_000, date: d)
    clothes_done_for_window = true
  end
  month_days.sample(rand(2..4)).sort.each do |d|
    add_txn!(user: user, categories: categories, title: "Shopping",
             description: ["Stationery", "Home goods", "Gift"].sample,
             amount: rand(500..2_000), date: d)
  end

  # -------------------- Income LAST: balance month --------------------
  month_expense_total = user.transactions
                           .where(date: m_first..m_last, transaction_type: "expense")
                           .sum(:amount)

  surplus = if full_month
              rand(3_000..12_000)
            else
              rand(1_000..6_000)
            end

  salary_amt = month_expense_total + surplus
  add_txn!(user: user, categories: categories, title: "Income",
           description: "Monthly salary", amount: salary_amt, date: salary_day, type: "income")
  # -------------------------------------------------------------------
end

# ---------- Seed a short, realistic chat history ----------
puts "Creating a short chat history…"
now = Time.zone.now
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
deposit_day = Date.current.change(day: [5, Date.current.day].min)
Message.create!(
  user: user, role: "user",
  content: "Add a savings deposit of 15,000 yen to my Trip to France fund for this month.",
  created_at: now - 6.minutes, updated_at: now - 6.minutes
)
Message.create!(
  user: user, role: "assistant",
  content: <<~AI.strip,
    Got it — here’s a draft deposit into your Trip to France fund.

    ```DRAFT_TX
    {"description":"Saving deposit","amount":15000,"transaction_type":"expense","date":"#{deposit_day}","category_title":"Savings"}
    ```
    Confirm to save?
  AI
  created_at: now - 5.minutes, updated_at: now - 5.minutes
)

puts "Done! 🌱 Food fixed at ~¥55k/mo (pro-rated this month), Utilities highest, Food second; Trip to France seeded to goal–¥20k; salary balances each month from ¥100k start."
