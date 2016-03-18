#!/usr/bin/env ruby

require "getoptlong"
require "ostruct"
require "fileutils"

# TODO:
# build test files for each type
#    test with sample to verify it doesn't change
#    asset w/ inflation
#    asset w/o inflation
#    asset and debt
#    asset with deposit
#    asset with withdrawl
#    asset with interest
#    debt with deposit
#    debt with interest
#    debt with interest and payment
#    asset and income
#    asset and expense
#    asset and debt with recurring deposit
#    asset and debt with recurring expense
#    test relative months
#    test absolute months
# build my own input file
# support absolute month/year
# 
# TODO: future features
# allow for resetting asset/debt 
# plan vs actual?
# monte carlo

# entry definition
# "id"          : data set unique string, used for associating "interest" with an account
# "type"        : type of entry as follows:
#    asset        : generally a positive balance bank or investment account, current/starting balance
#    debt         : generally a negative balance loan or credit account, current/starting balance
#    deposit      : increase to an asset balance
#    withdrawl    : decrease to an asset balance
#    interest     : positive/negative annual percentage rate interest/gain for asset or debit
#    payment      : decreast to a debt, assume includes interest and principle
#    income       : increase to total, use when interest does not apply
#    expense      : decrease to total, use when interest deos not apply
#    inflation    : post total reduction, can be multiple ranges
# "reference"   : id of entry this applies to, used with deposit|withdrawl|interest|payment
# "description" : description of entry, this field is not parsed
# "comment"     : general comment about entry, this field is not parsed
# "start_month" : start month for entry, 1-12
# "start_year"  : start year  for entry, 0 means start month is relative, 0-N
# "end_month"   : end   month for entry, 1-12, -1 means never ends
# "end_year"    : end   year  for entry, 0 means end month is relative, 0-N
# "amount"      : positive or negative amount

# globals
@entries = []

#-----------------------------------------------------------------------
def load_entries(in_file)
  @entries = []
  entry = {}
  lines = File.readlines(in_file)
  lines.each do |line|
    parts = line.split("#")                    # get line before comment
    parts = parts[0].strip.split(":")          # split key and value
    if parts.length == 2
        key   = parts[0].strip
        value = parts[1].strip
        entry = {} if key === "id"             # assume entry starts with "id"
        value = value.to_i if key === "start_month"
        value = value.to_i if key === "start_year"
        value = value.to_i if key === "end_month"
        value = value.to_i if key === "end_year"
        value = value.to_f if key === "amount"
        entry[key] = value
        @entries << entry if key === "amount"  # assume entry ends with "amount"
    end
  end
end

#-----------------------------------------------------------------------
def save_entries(out_file, force)
  if not force and File.exists?(out_file)
    puts "File \"%s\" exists, continue? (ctrl-C to exit):" % out_file
    gets
  end
  file = File.open(out_file, "w")
  if (file)
    @entries.each do |entry|
      file.puts ""
      file.puts "%-20s: %s"   % [ "id",          entry["id"]          ]
      file.puts "%-20s: %s"   % [ "type",        entry["type"]        ]
      file.puts "%-20s: %s"   % [ "reference",   entry["reference"]   ]
      file.puts "%-20s: %s"   % [ "description", entry["description"] ]
      file.puts "%-20s: %s"   % [ "comment",     entry["comment"]     ]
      file.puts "%-20s: %d"   % [ "start_month", entry["start_month"] ]
      file.puts "%-20s: %d"   % [ "start_year",  entry["start_year"]  ]
      file.puts "%-20s: %d"   % [ "end_month",   entry["end_month"]   ]
      file.puts "%-20s: %d"   % [ "end_year",    entry["end_year"]    ]
      file.puts "%-20s: %.2f" % [ "amount",      entry["amount"]      ]
    end
  end
end

#-----------------------------------------------------------------------
def usage
print "Usage: #{$scriptname} [options]
Options:
  -h | --help            # Help message
  -i | --in-file         # Input portfolio plan file (see sample.txt for starting point)
  -o | --out-file        # Output modified portfolio plan file
  -m | --months          # Total months to show (default 120, or 10 years)
"
end

#-----------------------------------------------------------------------
def get_reference_amount(reference)
  amount = 0
  @entries.each_with_index do |entry, index|
    if entry["id"] === reference
      amount = @entries[index]["amount"]
    end
  end
  amount
end

#-----------------------------------------------------------------------
def deposit_to_reference(reference, amount)
  @entries.each_with_index do |entry, index|
    if entry["id"] === reference
      @entries[index]["amount"] += amount
    end
  end
end

#-----------------------------------------------------------------------
def withdrawl_from_reference(reference, amount)
  @entries.each_with_index do |entry, index|
    if entry["id"] === reference
      @entries[index]["amount"] += amount
    end
  end
end

#-----------------------------------------------------------------------
parser = GetoptLong.new
parser.set_options(
["-i", "--in-file",  GetoptLong::REQUIRED_ARGUMENT],
["-o", "--out-file", GetoptLong::REQUIRED_ARGUMENT],
["-m", "--months",   GetoptLong::REQUIRED_ARGUMENT],
["-h", "--help",     GetoptLong::NO_ARGUMENT]
)

options = OpenStruct.new
options.in_file = nil
options.out_file = nil
options.months = 120

loop do
  begin
    opt, arg = parser.get
    break if not opt

    case opt
    when "-h"
      usage()
      exit 0
    when "-i"
      options.in_file = arg
    when "-o"
      options.out_file = arg
    when "-m"
      options.months = arg.to_i
    end

  rescue => err
    puts err
    break
  end
end

load_entries(options.in_file)         if not options.in_file.nil?
save_entries(options.out_file, false) if not options.out_file.nil?

#-----------------------------------------------------------------------
# determine current assets and debts
assets = 0
debts  = 0
total  = 0
@entries.each do |entry|
  amount = entry["amount"]
  start_month = entry["start_month"]
  end_month   = entry["end_month"]
  # TODO: allow for absolute M/Y, including prior to current date?
  if start_month == end_month and start_month == 0
    assets += amount if entry["type"] === "asset"
    debts  += amount if entry["type"] === "debt"
  end
end
total = assets + debts

# determine on going total without inflation
totals_wo_inflation = []
month = 0
while month <= options.months
  income = 0
  expenses = 0
  @entries.each do |entry|
    # get values
    amount      = entry["amount"]
    start_month = entry["start_month"]
    end_month   = entry["end_month"]

    # update total for this month
    if start_month <= month and (end_month == -1 or end_month >= month)
      income    += amount if entry["type"] === "income"
      expenses  += amount if entry["type"] === "expense"

      if entry["type"] === "interest"
        gain = get_reference_amount(entry["reference"])
        gain = gain * (amount/12.0) 
        # update reference account for next interest calculation
        deposit_to_reference(entry["reference"], gain)
        # update income for on going total calculation
        income += gain
      end

      if entry["type"] === "deposit" or entry["type"] === "payment"
        # update reference account for interest calculation
        deposit_to_reference(entry["reference"], amount)
        # update income for on going total calculation
        income += amount
      end

      if entry["type"] === "withdrawl"
        # update reference account for interest calculation
        withdrawl_from_reference(entry["reference"], amount)
        # update income for on going total calculation
        income += amount
      end
    end
  end
  totals_wo_inflation[month] = total
  total = total + income + expenses
  month = month + 1
end
#save_entries("debug.txt", true)

# assume we can adjust for inflation after totals calculated
totals_w_inflation = []
current_inflation_rate   = 0.0
current_inflation_factor = 1.0
month = 0
while month <= options.months
  # calculate inflaction adjusted total
  total = totals_wo_inflation[month]
  total = total * current_inflation_factor 
  totals_w_inflation[month] = total

  # update inflation rate/factor
  @entries.each do |entry|
    # get values
    amount      = entry["amount"]
    start_month = entry["start_month"]
    end_month   = entry["end_month"]

    # update total for this month
    if start_month <= month and (end_month == -1 or end_month >= month)
      current_inflation_rate = amount if entry["type"] === "inflation"
    end
  end
  current_inflation_factor = current_inflation_factor - (current_inflation_rate/12.0)
  month = month + 1
end

# display totals
month = 0
while month < options.months
  total1 = totals_wo_inflation[month]
  total2 = totals_w_inflation[month]
  #puts "%4d\t%.2f\t%.2f" % [month, total1, total2]
  puts "%4d\t%.2f\t%.2f\t\t%.2f" % [month, total1, total2, total2-total1]
  month = month + 1
end




