#!/usr/bin/env ruby

require "getoptlong"
require "ostruct"
require "fileutils"

# globals
@entries = []

#-----------------------------------------------------------------------
# Usage
#-----------------------------------------------------------------------
def usage
print "Usage: #{$scriptname} [options]
Options:
  -h | --help            # Help message
  -i | --in_file         # Input portfolio plan file (use -o without -i for sample)
  -o | --out_file        # Output modified portfolio plan file

"
end

#-----------------------------------------------------------------------
# Usage
#-----------------------------------------------------------------------
def build_default_entries
  @entries = []
  # assets
  entry = {}
  entry["id"]          = "acount1"
  entry["type"]        = "asset"
  entry["description"] = "account 1"
  entry["comment"]     = "asset"
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
  entry["comment"]     = "asset"
  entry["start_month"] = 0
  entry["start_year"]  = 0
  entry["end_month"]   = 0
  entry["end_year"]    = 0
  entry["amount"]      = 300000
  @entries << entry
  entry = {}
  entry["id"]          = "acount3"
  entry["type"]        = "debt"
  entry["description"] = "account 2"
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
# Get options
#-----------------------------------------------------------------------
parser = GetoptLong.new
parser.set_options(
["-h", "--help", GetoptLong::NO_ARGUMENT],
["-i", "--in_file", GetoptLong::REQUIRED_ARGUMENT],
["-o", "--out_file", GetoptLong::REQUIRED_ARGUMENT]
)

options = OpenStruct.new
options.in_file = nil
options.out_file = nil

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
    end

  rescue => err
    puts err
    break
  end
end

build_default_entries if options.in_file.nil?
save_entries(options) if not options.out_file.nil?

# relative month range
month = 0
month_max = 12

# determine current assets and debts
assets = 0
debts  = 0
total  = 0
@entries.each do |entry|
  amount = entry["amount"]
  assets += amount if entry["type"] === "asset"
  debts  += amount if entry["type"] === "debt"
end
total = assets + debts

# determine on going total
while month <= month_max
  income = 0
  expenses = 0
  @entries.each do |entry|
    amount = entry["amount"]
    start_month = entry["start_month"]
    end_month   = entry["end_month"]
    if start_month <= month and (end_month == -1 or end_month >= month)
      income    += amount if entry["type"] === "income"
      expenses  += amount if entry["type"] === "expense"
    end
  end

  puts "%4d %d" % [month, total]
  total = total + income + expenses
  month = month + 1
end

# TODO:
# generate default output file
# test if output file exists
# parse input file
# skip input comments
# pass input comments thru to out file
# convert month to year/month
# finish all entries (in the in_file?)
# how to add in inflation?
# 
# multiple accounts
# assets
# debts
# mutliple monthly transactions
# income
# expenses
# future income
# future expenses
# inflation, single, ranges
# account performace, single, ranges
# 
# monte carlo
#
# plan vs actual?




