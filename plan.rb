#!/usr/bin/env ruby

require "getoptlong"
require "ostruct"
require "fileutils"

# TODO:
# parse input file
# skip input comments
# pass input comments thru to out file
# convert month to year/month
# finish all entries (in the in_file?)
# how to add in inflation?
# allow for resetting asset/debt 
# 
# future income
# future expenses
# inflation, single, ranges
# account performace, single, ranges
# plan vs actual?
# monte carlo

# entry definition
# "id"          : data set unique string, used for associating "interest" with an account
# "type"        : type of entry as follows:
#    asset        : generally a positive balance bank or investment account, current/starting balance
#    debt         : generally a negative balance loan or credit account, current/starting balance
#    deposit      : increase to an asset balance
#    withdrawl    : decrease to an asset balance
#    interest     : positive/negative annual percentage rate for asset or debit
#    payment      : decreast to a debt, assume includes interest and principle
#    income       : increase to total                                               TODO: should this be deposit?
#    expense      : decrease to total                                               TODO: should this be withdrawl?
#    inflation    : post total reduction, can be multiple ranges
# "description" : description of entry, this field is not parsed
# "comment"     : general comment about entry, this field is not parsed
# "start_month" : start month for entry, 1-12
# "start_year"  : start year  for entry, 0 means start month is relative, 0-N       TODO: support absolute
# "end_month"   : end   month for entry, 1-12, -1 means never ends
# "end_year"    : end   year  for entry, 0 means end month is relative, 0-N         TODO: support absolute
# "amount"      : positive or negative amount

# globals
@entries = []

#-----------------------------------------------------------------------
def build_default_entries
  @entries = []

  # inflation
  entry = {}
  entry["id"]          = "inflation1"
  entry["type"]        = "inflation"
  entry["description"] = "projected inflation range 1"
  entry["comment"]     = "amount field used for inflation rate, expect low for next 2 years"
  entry["start_month"] = 0
  entry["start_year"]  = 0
  entry["end_month"]   = 24
  entry["end_year"]    = 0
  entry["amount"]      = 0.03
  @entries << entry
  entry = {}
  entry["id"]          = "inflation2"
  entry["type"]        = "inflation"
  entry["description"] = "projected inflation range 2"
  entry["comment"]     = "amount field used for inflation rate, expect to rise after 2 years"
  entry["start_month"] = 24
  entry["start_year"]  = 0
  entry["end_month"]   = -1
  entry["end_year"]    = 0
  entry["amount"]      = 0.10
  @entries << entry

  # assets
  entry = {}
  entry["id"]          = "acount1"
  entry["type"]        = "asset"
  entry["description"] = "account 1"
  entry["comment"]     = "some account that is an asset"
  entry["start_month"] = 0
  entry["start_year"]  = 0
  entry["end_month"]   = 0
  entry["end_year"]    = 0
  entry["amount"]      = 100000
  @entries << entry
  entry = {}
  entry["id"]          = "acount2"
  entry["type"]        = "asset"
  entry["description"] = "account 2"
  entry["comment"]     = "another account that is an asset"
  entry["start_month"] = 0
  entry["start_year"]  = 0
  entry["end_month"]   = 0
  entry["end_year"]    = 0
  entry["amount"]      = 300000
  @entries << entry
  entry = {}
  entry["id"]          = "acount3"
  entry["type"]        = "debt"
  entry["description"] = "some account that is a debt"
  entry["comment"]     = "debt"
  entry["start_month"] = 0
  entry["start_year"]  = 0
  entry["end_month"]   = 0
  entry["end_year"]    = 0
  entry["amount"]      = -200000
  @entries << entry

  # income
  entry = {}
  entry["id"]          = "income1"
  entry["type"]        = "income"
  entry["description"] = "person1 pay"
  entry["comment"]     = "income, next 10 years"
  entry["start_month"] = 0
  entry["start_year"]  = 0
  entry["end_month"]   = 120
  entry["end_year"]    = 0
  entry["amount"]      = 1000
  @entries << entry
  entry = {}
  entry["id"]          = "income2"
  entry["type"]        = "income"
  entry["description"] = "person1 pay"
  entry["comment"]     = "income, next 15 years"
  entry["start_month"] = 0
  entry["start_year"]  = 0
  entry["end_month"]   = 180
  entry["end_year"]    = 0
  entry["amount"]      = 2000
  @entries << entry

  # expenses
  entry = {}
  entry["id"]          = "expense1"
  entry["type"]        = "expense"
  entry["description"] = "utilities"
  entry["comment"]     = "expense, never ends"
  entry["start_month"] = 0
  entry["start_year"]  = 0
  entry["end_month"]   = -1
  entry["end_year"]    = 0
  entry["amount"]      = -100
  @entries << entry
  entry = {}
  entry["id"]          = "expense2"
  entry["type"]        = "expense"
  entry["description"] = "credit card"
  entry["comment"]     = "expense, average, never ends"
  entry["start_month"] = 0
  entry["start_year"]  = 0
  entry["end_month"]   = -1
  entry["end_year"]    = 0
  entry["amount"]      = -1000
  @entries << entry
  entry = {}
  entry["id"]          = "expense3"
  entry["type"]        = "expense"
  entry["description"] = "car loan"
  entry["comment"]     = "expense, 2 years left"
  entry["start_month"] = 0
  entry["start_year"]  = 0
  entry["end_month"]   = 24
  entry["end_year"]    = 0
  entry["amount"]      = -500
  @entries << entry
end

#-----------------------------------------------------------------------
def save_entries options
  if File.exists?(options.out_file)
    puts "File \"%s\" exists, continue? (ctrl-C to exit):" % options.out_file
    gets
  end
  file = File.open(options.out_file, "w")
  if (file)
    @entries.each do |entry|
      file.puts ""
      file.puts "%-20s: %s" % [ "id",          entry["id"]          ]
      file.puts "%-20s: %s" % [ "type",        entry["type"]        ]
      file.puts "%-20s: %s" % [ "description", entry["description"] ]
      file.puts "%-20s: %s" % [ "comment",     entry["comment"]     ]
      file.puts "%-20s: %d" % [ "start_month", entry["start_month"] ]
      file.puts "%-20s: %d" % [ "start_year",  entry["start_year"]  ]
      file.puts "%-20s: %d" % [ "end_month",   entry["end_month"]   ]
      file.puts "%-20s: %d" % [ "end_year",    entry["end_year"]    ]
      file.puts "%-20s: %d" % [ "amount",      entry["amount"]      ]
    end
  end
end

#-----------------------------------------------------------------------
def usage
print "Usage: #{$scriptname} [options]
Options:
  -h | --help            # Help message
  -i | --in-file         # Input portfolio plan file (use -o without -i for sample)
  -o | --out-file        # Output modified portfolio plan file
  -m | --months          # Total months to show (default 120, or 10 years)

"
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

build_default_entries if options.in_file.nil?
save_entries(options) if not options.out_file.nil?

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
    end
  end
  totals_wo_inflation[month] = total
  total = total + income + expenses
  month = month + 1
end

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




