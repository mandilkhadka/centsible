# db/seeds.rb
require "faker"
require "date"

puts "Cleaning up…"
Transaction.delete_all
Saving.delete_all  if defined?(Saving)
Category.delete_all
Message.delete_all if defined?(Message)
User.delete_all

puts "Creating user…"
user = User.create!(
  name: "Test User",
  email: "test@test.com",
  password: "123123",
  starting_balance: 180_000 # small cushion so pre-6th bills don't go negative
)

# -------------------- Categories --------------------
TITLES = [
  "Income",
  "Food",
  "Utilities",
  "Commute",
  "Entertainment",
  "Shopping",
  "Health",
  "Savings",   # deposits into piggy banks (expense)
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

# -------------------- Helpers --------------------
def month_first(d) = Date.new(d.year, d.month, 1)
def month_last(d)  = (month_first(d).next_month - 1)
def weekdays(days) = days.select { |dt| (1..5).include?(dt.wday) }
def weekends(days) = days.select { |dt| dt.saturday? || dt.sunday? }
def randi(r)       = r.is_a?(Range) ? rand(r).to_i : r

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
  step = 5_000
  target_total = (target_total / step) * step
  amounts = Array.new(months_count, 0)
  remaining = target_total

  i = 0
  while remaining >= min && i < months_count
    amounts[i] = min
    remaining -= min
    i += 1
  end

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

# -------------------- Deterministic randomness --------------------
today = Date.current
seed  = (ENV["SEED"] || today.strftime("%Y%m%d")).to_i
srand(seed)
Faker::Config.random = Random.new(seed)

# -------------------- Date window: Jan 1 → today --------------------
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

# -------------------- Savings goals --------------------
puts "Creating savings goals…"
POKEPARK_GOAL    = 160_000   # Premium day out + merch for parent & 3yo
POKEPARK_LEFT    = 20_000    # leave 20k for live top-up
DOWNPAYMENT_GOAL = 1_000_000
PHONE_GOAL       = 120_000

savings_goals = [
  { title: "Down payment for new appartment",    goal: DOWNPAYMENT_GOAL },
  { title: "Poképark Tokyo Day (Spring 2026)",   goal: POKEPARK_GOAL },
  { title: "New phone replacement",              goal: PHONE_GOAL }
]
piggy_banks = savings_goals.map { |attrs| user.savings.create!(attrs) }

pokepark = piggy_banks.find { |s| s.title == "Poképark Tokyo Day (Spring 2026)" }
dp_fund  = piggy_banks.find { |s| s.title == "Down payment for new appartment" }
phone    = piggy_banks.find { |s| s.title == "New phone replacement" }
raise "Savings not created correctly" unless pokepark && dp_fund && phone

# Plan Poképark deposits = goal - 20k across the window (<= 40k/mo, round numbers)
pokepark_target_total = POKEPARK_GOAL - POKEPARK_LEFT  # 140,000
pokepark_plan = build_round_deposit_plan(
  months_count: months.size,
  target_total: pokepark_target_total,
  min: 10_000, max: 40_000
)

# -------------------- Bills (Utilities) --------------------
BILLS = {
  "Rent"          => { amount: 80_000,         due: 1  },
  "Electric bill" => { amount: 5_500..9_000,   due: 12 },
  "Gas bill"      => { amount: 3_000..6_000,   due: 15 },
  "Water bill"    => { amount: 2_200..3_800,   due: 20 },
  "Mobile plan"   => { amount: 3_500..5_000,   due: 8  },
  "Home internet" => { amount: 4_800..6_200,   due: 10 },
  "Streaming sub" => { amount: 900..1_500,     due: 5  }
}

# Caps so Food stays #2 (< 55k)
CATEGORY_CAPS = {
  "Savings"       => 50_000, # total per month across all piggy banks
  "Entertainment" => 45_000,
  "Shopping"      => 35_000,
  "Health"        => 18_000,
  "Others"        => 35_000,
  "Commute"       => 25_000
}

puts "Creating realistic transactions…"

months.each_with_index do |range, mi|
  m_first = range.first
  m_last  = range.last
  full_month    = (m_last == month_last(m_first))
  month_days    = (m_first..m_last).to_a
  days_elapsed  = month_days.size
  days_in_month = month_last(m_first).day
  is_current_month = (m_first.month == today.month && m_first.year == today.year)

  # ---- Salary (only income) on the 6th; skip for current month if today < 6th
  salary_day = Date.new(m_first.year, m_first.month, 6)
  if salary_day <= m_last
    add_txn!(user: user, categories: categories, title: "Income",
             description: "Monthly salary", amount: 350_000,
             date: salary_day, type: "income")
  end

  # ---- Utilities (largest category)
  BILLS.each do |desc, cfg|
    due  = [cfg[:due], month_last(m_first).day].min
    date = Date.new(m_first.year, m_first.month, due)
    next if date > m_last
    amt  = randi(cfg[:amount])
    add_txn!(user: user, categories: categories, title: "Utilities",
             description: desc, amount: amt, date: date)
  end

  # ---- Commute: pass + small extras
  pass_amt = rand(12_000..18_000)
  add_txn!(user: user, categories: categories, title: "Commute",
           description: "Commuter pass (30-day)", amount: pass_amt,
           date: [m_first + 2, m_last].min)
  if pass_amt < CATEGORY_CAPS["Commute"] && full_month
    taxi_budget = [CATEGORY_CAPS["Commute"] - pass_amt, 6_000].min
    if taxi_budget > 0
      split_total_random(taxi_budget, rand(1..2), min_per: 1_000).each do |amt|
        day = (m_first+10..m_last-1).to_a.sample
        add_txn!(user: user, categories: categories, title: "Commute",
                 description: "Taxi / ride-hail", amount: amt, date: day)
      end
    end
  end

  # ---------------------- FOOD: lock the total ----------------------
  food_target = if full_month
                  55_000
                else
                  ((55_000 * (days_elapsed.to_f / days_in_month)).round(-2)).to_i
                end

  # Coffee (weekdays)
  weekdays(month_days).each do |d|
    add_txn!(user: user, categories: categories, title: "Food",
             description: "Starbucks coffee", amount: 540, date: d)
  end
  coffee_total = weekdays(month_days).size * 540

  # Eating out
  weekend_pool  = weekends(month_days)
  eatout_count  = full_month ? rand(3..6) : [[(6.0 * days_elapsed / days_in_month).round, 1].max, weekend_pool.size].min
  eatout_days   = weekend_pool.sample(eatout_count).sort
  eatout_amounts = eatout_days.map { rand(900..2_400) }
  eatout_total   = eatout_amounts.sum

  # Groceries to hit the target
  grocery_visits     = full_month ? rand(4..5) : [[(5.0 * days_elapsed / days_in_month).ceil, 1].max, 5].min
  min_grocery_total  = grocery_visits * 1_200
  while (food_target - coffee_total - eatout_total) < min_grocery_total && eatout_days.any?
    removed = eatout_amounts.pop
    eatout_days.pop
    eatout_total -= removed
  end
  grocery_total   = [food_target - coffee_total - eatout_total, min_grocery_total].max
  grocery_days    = month_days.group_by(&:cweek).values.map { |w| w.sample(1) }.flatten.first(grocery_visits).sort
  grocery_amounts = split_total_random(grocery_total, grocery_days.size, min_per: 1_200)

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

  # ---- Savings (keep total <= cap so Food stays #2)
  deposit_date = [m_first + rand(2..6), m_last].min
  monthly_savings_total = 0
  savings_cap = CATEGORY_CAPS["Savings"]

  # If it's the current month and salary hasn't arrived yet, SKIP savings this month
  salary_reached = (salary_day <= m_last)
  unless is_current_month && !salary_reached
    # Poképark (planned)
    poke_amt = pokepark_plan[mi].to_i
    if poke_amt > 0 && monthly_savings_total + poke_amt <= savings_cap
      add_txn!(user: user, categories: categories, title: "Savings",
               description: "Saving deposit - Poképark Tokyo Day (Spring 2026)",
               amount: poke_amt, date: deposit_date, saving: pokepark)
      monthly_savings_total += poke_amt
    end

    # helper to add small deposits without breaking the cap
    add_small_deposit = lambda do |fund, label, min_amt, max_amt|
      left = savings_cap - monthly_savings_total
      return if left < min_amt
      amt = [rand(min_amt..max_amt), left].min
      add_txn!(user: user, categories: categories, title: "Savings",
               description: "Saving deposit - #{label}", amount: amt,
               date: deposit_date, saving: fund)
      monthly_savings_total += amt
    end

    add_small_deposit.call(dp_fund, "Down payment for new appartment", 5_000, 10_000)
    add_small_deposit.call(phone,   "New phone replacement",           3_000, 6_000)
  end

  # ---- Base Health / Entertainment / Shopping noise
  month_days.sample(rand(1..2)).sort.each do |d|
    add_txn!(user: user, categories: categories, title: "Health",
             description: ["Pharmacy", "Vitamins"].sample,
             amount: rand(900..3_000), date: d)
  end

  ent_days = month_days.sample(rand(2..4)).sort
  ent_days.each do |d|
    add_txn!(user: user, categories: categories, title: "Entertainment",
             description: ["Cinema", "Karaoke", "Arcade", "Museum"].sample,
             amount: rand(700..3_000), date: d)
  end
  if rand < 0.35 && full_month && (m_last - m_first) >= 10
    d = (m_first+5..m_last-2).to_a.sample
    add_txn!(user: user, categories: categories, title: "Entertainment",
             description: ["Concert ticket", "Theme park day"].sample,
             amount: rand(5_000..10_000), date: d)
  end

  month_days.sample(rand(2..4)).sort.each do |d|
    add_txn!(user: user, categories: categories, title: "Shopping",
             description: ["Stationery", "Home goods", "Gift"].sample,
             amount: rand(500..2_000), date: d)
  end

  # ---- Expense top-up so net savings stay small (full months only)
  if full_month
    cat_totals = user.transactions
                    .joins(:category)
                    .where(date: m_first..m_last, transaction_type: "expense")
                    .group("categories.title").sum(:amount)

    spent_now    = cat_totals.values.sum
    target_spend = 350_000 - rand(3_000..8_000) # tiny surplus
    remaining    = [target_spend - spent_now, 0].max

    if remaining > 0
      extra_catalog = {
        "Entertainment" => [
          ["Night out & drinks", 3_000..8_000],
          ["Live house/concert", 4_000..9_000],
          ["Museum + cafe",      2_000..6_000]
        ],
        "Shopping" => [
          ["Household goods",   2_000..7_000],
          ["Clothes",           3_000..10_000],
          ["Small appliance",   5_000..15_000]
        ],
        "Health" => [
          ["Clinic visit",      4_000..8_000],
          ["Pharmacy restock",  1_500..4_000]
        ],
        "Others" => [
          ["Household services", 2_000..6_000],
          ["Gift",               2_000..8_000]
        ],
        "Commute" => [
          ["Late-night taxi",   1_500..3_500]
        ]
      }

      loop_guard = 0
      while remaining > 0 && loop_guard < 200
        loop_guard += 1
        cat = extra_catalog.keys.sample
        cap = CATEGORY_CAPS[cat]
        current_cat = cat_totals[cat] || 0
        allow = [cap - current_cat, remaining, 0].max
        if allow >= 1_000
          label, rng = extra_catalog[cat].sample
          amt = [randi(rng), allow].min.round(-2)
          day = (m_first+15..m_last).to_a.sample
          add_txn!(user: user, categories: categories, title: cat,
                   description: label, amount: amt, date: day)
          cat_totals[cat] = current_cat + amt
          remaining      -= amt
        end
        break if remaining < 1_000
      end
    end
  end
end

# -------------------- Seed a 3×3 chat history --------------------
puts "Creating a short chat history…"
now = Time.zone.now

# 1) User asks to log a coffee today
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

# 2) User asks about last month's Food spend
Message.create!(
  user: user, role: "user",
  content: "How much did I spend on Food last month?",
  created_at: now - 8.minutes, updated_at: now - 8.minutes
)
Message.create!(
  user: user, role: "assistant",
  content: "- You target about ¥55,000 for Food per month.\n- Last month should be close to that.\n- Tip: cutting 2 take-outs could save ~¥3,000–¥4,000.",
  created_at: now - 7.minutes, updated_at: now - 7.minutes
)

# 3) User requests a Poképark savings deposit draft
deposit_day = Date.current.change(day: [5, Date.current.day].min) # early month; clamp if today < 5
Message.create!(
  user: user, role: "user",
  content: "Add a savings deposit of 10,000 yen to my Poképark fund for this month.",
  created_at: now - 6.minutes, updated_at: now - 6.minutes
)
Message.create!(
  user: user, role: "assistant",
  content: <<~AI.strip,
    Got it — here’s a draft deposit into your Poképark fund.

    ```DRAFT_TX
    {"description":"Saving deposit","amount":10000,"transaction_type":"expense","date":"#{deposit_day}","category_title":"Savings"}
    ```
    Confirm to save?
  AI
  created_at: now - 5.minutes, updated_at: now - 5.minutes
)

puts "Done! 🌱 Salary ¥350k on the 6th; Food ~¥55k/mo and stays #2 after Utilities; "
puts "Poképark fund seeded to goal–¥20k; piggy banks: Down payment, Poképark, New phone. "
puts "Savings skipped before payday in the current month and starting balance raised to keep you positive."
