#!/usr/bin/env ruby

require "getoptlong"
require "ostruct"
require "fileutils"
require "date"

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
# "start_month" : start month for entry, relative 0-n
# "end_month"   : end   month for entry, relative 0-n, -1 means never ends
# "abs_start_month" : (optional) absolute start month for entry, 1-12, will override start_month
# "abs_start_year"  : (optional) absolute start year  for entry, YYYY, will override start_month
# "abs_end_month"   : (optional) absolute end   month for entry, 1-12, will override end_month
# "abs_end_year"    : (optional) absolute end   year  for entry, YYYY, will override end_month
# "amount"      : positive or negative amount

# globals
@entries = []
@entries_wo = []
@entries_w  = []

#-----------------------------------------------------------------------
def load_entries(options)
  @entries = []
  entry = {}
  lines = File.readlines(options.in_file)
  lines.each do |line|
    parts = line.split("#")                    # get line before comment
    parts = parts[0].strip.split(":")          # split key and value
    if parts.length == 2
        key   = parts[0].strip
        value = parts[1].strip
        entry = {} if key === "id"             # assume entry starts with "id"
        value = value.to_i if key === "start_month"
        value = value.to_i if key === "end_month"
        value = value.to_i if key === "abs_start_month"
        value = value.to_i if key === "abs_start_year"
        value = value.to_i if key === "abs_end_month"
        value = value.to_i if key === "abs_end_year"
        value = value.to_f if key === "amount"
        entry[key] = value

        if key === "amount"  # assume entry ends with "amount"
          # convert abs_start_* to relative start_month
          if entry.key?("abs_start_month") and entry.key?("abs_start_year")
            temp_month = Date.today.month
            temp_year  = Date.today.year
            temp_month = options.start_month if not options.start_month.nil?
            temp_year  = options.start_year  if not options.start_year.nil?
            total_months1 = (temp_month-1) + (12*temp_year)                    # base total months for this run
            temp_month = entry["abs_start_month"]
            temp_year  = entry["abs_start_year"]
            total_months2 = (temp_month-1) + (12*temp_year)                    # abs start total months
            entry["start_month"] = total_months2 - total_months1
          end
          # convert abs_end_* to relative end_month
          if entry.key?("abs_end_month") and entry.key?("abs_end_year")
            temp_month = Date.today.month
            temp_year  = Date.today.year
            temp_month = options.start_month if not options.start_month.nil?
            temp_year  = options.start_year  if not options.start_year.nil?
            total_months1 = (temp_month-1) + (12*temp_year)                    # base total months for this run
            temp_month = entry["abs_end_month"]
            temp_year  = entry["abs_end_year"]
            total_months2 = (temp_month-1) + (12*temp_year)                    # abs end total months
            entry["end_month"] = total_months2 - total_months1
          end

          @entries << entry
        end # key === amount
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
      file.puts "%-20s: %d"   % [ "end_month",   entry["end_month"]   ]
      file.puts "%-20s: %d"   % [ "abs_start_month",  entry["abs_start_month"] ] if entry.key?("abs_start_month")
      file.puts "%-20s: %d"   % [ "abs_start_year",   entry["abs_start_year"]  ] if entry.key?("abs_start_year")
      file.puts "%-20s: %d"   % [ "abs_end_month",    entry["abs_end_month"]   ] if entry.key?("abs_end_month")
      file.puts "%-20s: %d"   % [ "abs_end_year",     entry["abs_end_year"]    ] if entry.key?("abs_end_year")
      file.puts "%-20s: %.2f" % [ "amount",      entry["amount"]      ]
    end
  end
end

DISOPT_NONE                         = 0x0000
DISOPT_MMYYYY                       = 0x0001
DISOPT_TOTAL_WO_INFL                = 0x0002
DISOPT_TOTAL_W__INFL                = 0x0004
DISOPT_IN_THOUSANDS                 = 0x0010
DISOPT_WO_AND_THOUS                 = 0x0012
DISOPT_W__AND_THOUS                 = 0x0014
DISOPT_ACCOUNTS                     = 0x0100
DISOPT_ACCOUNTS_INFO                = 0x0200
DISOPT_ACCOUNTS_INCOME_EXPENSE      = 0x0400
DISOPT_ACCOUNTS_INFLATION_INTEREST  = 0x0800

#-----------------------------------------------------------------------
def usage
print "Usage: #{$scriptname} [options]
Options:
  -h | --help            # Help message
  -i | --in-file         # Input portfolio plan file (see sample.txt for starting point)
  -o | --out-file        # Output modified portfolio plan file
  -m | --months          # Total months to show (default 120, or 10 years)
  -M | --start-month     # Start month for display
  -Y | --start-year      # Start year  for display
  -d | --display-opt     # Display options:
                           0x0001 - display month/year
                           0x0002 - display total w/o inflation adjustment
                           0x0004 - display total w   inflation adjustment
                           0x0010 - display numbers div 1000
                           0x0100 - display accounts as additional columns
                           0x0200 - display accounts info as rows above header
                           0x0400 - display accounts including income/expense/deposit/withdrawl
                           0x0800 - display accounts including inflation/interest
                           Example: 0x0014 displays month/year and total w/ inflation
"
end

#-----------------------------------------------------------------------
def get_reference_amount(given_entries, reference)
  amount = 0
  given_entries.each_with_index do |entry, index|
    if entry["id"] === reference
      amount = given_entries[index]["amount"]
    end
  end
  amount
end

#-----------------------------------------------------------------------
def set_to_reference(given_entries, reference, amount)
  given_entries.each_with_index do |entry, index|
    if entry["id"] === reference
      given_entries[index]["amount"] = amount
    end
  end
end

#-----------------------------------------------------------------------
def deposit_to_reference(given_entries, reference, amount)
  given_entries.each_with_index do |entry, index|
    if entry["id"] === reference
      given_entries[index]["amount"] += amount
    end
  end
end

#-----------------------------------------------------------------------
def withdrawl_from_reference(given_entries, reference, amount)
  given_entries.each_with_index do |entry, index|
    if entry["id"] === reference
      given_entries[index]["amount"] += amount
    end
  end
end

#-----------------------------------------------------------------------
parser = GetoptLong.new
parser.set_options(
["-i", "--in-file",     GetoptLong::REQUIRED_ARGUMENT],
["-o", "--out-file",    GetoptLong::REQUIRED_ARGUMENT],
["-m", "--months",      GetoptLong::REQUIRED_ARGUMENT],
["-M", "--start-month", GetoptLong::REQUIRED_ARGUMENT],
["-Y", "--start_year",  GetoptLong::REQUIRED_ARGUMENT],
["-d", "--display-opt", GetoptLong::REQUIRED_ARGUMENT],
["-h", "--help",        GetoptLong::NO_ARGUMENT]
)

options = OpenStruct.new
options.in_file = nil
options.out_file = nil
options.months = 120
options.start_month = nil
options.start_year = nil
# relative month, w/o and w/ inflation, div 1000
options.display_opt = 0x1110

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
    when "-M"
      options.start_month = arg.to_i
    when "-Y"
      options.start_year = arg.to_i
    when "-d"
      options.display_opt = arg.to_i(16)
    end

  rescue => err
    puts err
    break
  end
end

load_entries(options)                 if not options.in_file.nil?
save_entries(options.out_file, false) if not options.out_file.nil?
@entries.each do |entry|
  @entries_wo << entry.dup
  @entries_w  << entry.dup
end


# display account info
if (options.display_opt & DISOPT_ACCOUNTS_INFO) != DISOPT_NONE
  hdr_count = 0
  hdr_total = 12
  while hdr_count < hdr_total
    month_hdr    = ""
    total_wo_hdr = ""
    total_w_hdr  = ""
    accounts_hdr = ""
    month_hdr    = " "                     if hdr_count == 0
    month_hdr    = "  type"                if hdr_count == 1
    month_hdr    = "  reference"           if hdr_count == 2
    month_hdr    = "  description"         if hdr_count == 3
    month_hdr    = "  comment"             if hdr_count == 4
    month_hdr    = "  start_month"         if hdr_count == 5
    month_hdr    = "  end_month"           if hdr_count == 6
    month_hdr    = "  abs_start_month"     if hdr_count == 7
    month_hdr    = "  abs_start_year"      if hdr_count == 8
    month_hdr    = "  abs_end_month"       if hdr_count == 9
    month_hdr    = "  abs_end_year"        if hdr_count == 10
    month_hdr    = "  amount"              if hdr_count == 11
    total_wo_hdr = "\t%s" % [" "]          if hdr_count == 0 and (options.display_opt & DISOPT_TOTAL_WO_INFL) != DISOPT_NONE
    total_w_hdr  = "\t%s" % [" "]          if hdr_count == 0 and (options.display_opt & DISOPT_TOTAL_W__INFL) != DISOPT_NONE
    if (options.display_opt & DISOPT_ACCOUNTS) != DISOPT_NONE
      @entries.each do |entry|
        if (options.display_opt & DISOPT_ACCOUNTS_INCOME_EXPENSE) === DISOPT_NONE
          next if entry["type"] === "income"  or entry["type"] === "expense"
          next if entry["type"] === "deposit" or entry["type"] === "withdrawl"
        end
        if (options.display_opt & DISOPT_ACCOUNTS_INFLATION_INTEREST) === DISOPT_NONE
          next if entry["type"] === "inflation" or entry["type"] === "interest"
        end
        accounts_hdr << "\t%12s" % entry["id"]              if hdr_count == 0
        accounts_hdr << "\t%12s" % entry["type"]            if hdr_count == 1
        accounts_hdr << "\t%12s" % entry["reference"]       if hdr_count == 2
        accounts_hdr << "\t\"%12s\"" % entry["description"] if hdr_count == 3
        accounts_hdr << "\t\"%12s\"" % entry["comment"]     if hdr_count == 4
        accounts_hdr << "\t%12s" % entry["start_month"]     if hdr_count == 5
        accounts_hdr << "\t%12s" % entry["end_month"]       if hdr_count == 6
        accounts_hdr << "\t%12s" % entry["abs_start_month"] if hdr_count == 7
        accounts_hdr << "\t%12s" % entry["abs_start_year"]  if hdr_count == 8
        accounts_hdr << "\t%12s" % entry["abs_end_month"]   if hdr_count == 9
        accounts_hdr << "\t%12s" % entry["abs_end_year"]    if hdr_count == 10
        accounts_hdr << "\t%12.2f" % entry["amount"]        if hdr_count == 11
      end
    end
    
    puts "%-16s%14s%14s%s" % [month_hdr, total_wo_hdr, total_w_hdr, accounts_hdr]
    hdr_count = hdr_count + 1
  end
end

# display header
marker = " "
marker = "*" if (options.display_opt & DISOPT_TOTAL_W__INFL) != DISOPT_NONE
month_hdr    = " "
total_wo_hdr = " "
total_w_hdr  = " "
accounts_hdr = ""
account_types = []
month_hdr    = "DATE"
total_wo_hdr = "\t%s" % ["TOTAL"]      if (options.display_opt & DISOPT_TOTAL_WO_INFL) != DISOPT_NONE
total_w_hdr  = "\t%s" % ["TOTAL*"]     if (options.display_opt & DISOPT_TOTAL_W__INFL) != DISOPT_NONE
if (options.display_opt & DISOPT_ACCOUNTS) != DISOPT_NONE
  @entries.each do |entry|
    if (options.display_opt & DISOPT_ACCOUNTS_INCOME_EXPENSE) === DISOPT_NONE
          next if entry["type"] === "income"  or entry["type"] === "expense"
          next if entry["type"] === "deposit" or entry["type"] === "withdrawl"
    end
    if (options.display_opt & DISOPT_ACCOUNTS_INFLATION_INTEREST) === DISOPT_NONE
      next if entry["type"] === "inflation" or entry["type"] === "interest"
    end
    str = "%s%s" % [entry["id"], marker]
    accounts_hdr << "\t%12s" % str
    account_types << entry["type"]
  end
end
puts "%-16s%14s%14s%s" % [month_hdr, total_wo_hdr, total_w_hdr, accounts_hdr]


# build array of running account balances and overall totals
current_inflation_rate   = 0.0
current_inflation_factor = 1.0
balances_wo   = {}
balances_w    = {}
totals_wo     = {}
totals_w      = {}
month = 0
while month <= options.months
  
  # get total from assets/debts and gather running balances, no inflation
  total = 0
  @entries_wo.each do |entry|
    amount      = entry["amount"]
    start_month = entry["start_month"]
    end_month   = entry["end_month"]
    if start_month <= month and (end_month <= 0 or end_month >= month)
      total += amount if entry["type"] === "asset" or entry["type"] === "debt"
    end
  end
  if (options.display_opt & DISOPT_ACCOUNTS) != DISOPT_NONE
    balances = []
    @entries_wo.each do |entry|
      if (options.display_opt & DISOPT_ACCOUNTS_INCOME_EXPENSE) === DISOPT_NONE
            next if entry["type"] === "income"  or entry["type"] === "expense"
            next if entry["type"] === "deposit" or entry["type"] === "withdrawl"
      end
      if (options.display_opt & DISOPT_ACCOUNTS_INFLATION_INTEREST) === DISOPT_NONE
        next if entry["type"] === "inflation" or entry["type"] === "interest"
      end
      amount      = entry["amount"]
      start_month = entry["start_month"]
      end_month   = entry["end_month"]
      if start_month <= month and (end_month <= 0 or end_month >= month)
        balances << amount
      else
        balances << 0
      end
    end
    balances_wo[month] = balances
  end
  totals_wo[month] = total

  # get total from assets/debts and gather running balances, with inflation
  if (options.display_opt & DISOPT_TOTAL_W__INFL) != DISOPT_NONE
    total = 0
    @entries_w.each do |entry|
      amount = entry["amount"]
      total += amount if entry["type"] === "asset" or entry["type"] === "debt"
    end
    if (options.display_opt & DISOPT_ACCOUNTS) != DISOPT_NONE
      balances = []
      @entries_w.each do |entry|
        if (options.display_opt & DISOPT_ACCOUNTS_INCOME_EXPENSE) === DISOPT_NONE
              next if entry["type"] === "income"  or entry["type"] === "expense"
              next if entry["type"] === "deposit" or entry["type"] === "withdrawl"
        end
        if (options.display_opt & DISOPT_ACCOUNTS_INFLATION_INTEREST) === DISOPT_NONE
          next if entry["type"] === "inflation" or entry["type"] === "interest"
        end
        amount      = entry["amount"]
        start_month = entry["start_month"]
        end_month   = entry["end_month"]
        if start_month <= month and (end_month <= 0 or end_month >= month)
          balances << amount
        else
          balances << 0
        end
      end
      balances_w[month] = balances
    end
    totals_w[month] = total
  end

  # update account balances based on interest, income/expenses etc., no inflation
  @entries_wo.each do |entry|
    # get values
    amount      = entry["amount"]
    start_month = entry["start_month"]
    end_month   = entry["end_month"]

    # update total for this month
    if start_month <= month and (end_month <= 0 or end_month >= month)

      if entry["type"] === "interest"
        gain = get_reference_amount(@entries_wo, entry["reference"])
        gain = gain * (amount/12.0) 
        # update reference account for next interest calculation
        deposit_to_reference(@entries_wo, entry["reference"], gain)
      end

      if entry["type"] === "income" or entry["type"] === "deposit" or entry["type"] === "payment"
        # update reference account for interest calculation
        deposit_to_reference(@entries_wo, entry["reference"], amount)
      end

      if entry["type"] === "expense" or entry["type"] === "withdrawl"
        # update reference account for interest calculation
        withdrawl_from_reference(@entries_wo, entry["reference"], amount)
      end
    end
  end

  # update account balances based on interest, income/expenses etc., with inflation
  if (options.display_opt & DISOPT_TOTAL_W__INFL) != DISOPT_NONE
    current_inflation_factor = 1 + (current_inflation_rate/12.0)
    
    # apply inflation to assets/debts/income/expense
    @entries_w.each do |entry|
      # get values
      amount      = entry["amount"]

      # update total for this month
      if entry["type"] === "inflation"
        current_inflation_rate = amount
      end
      if entry["type"] === "debt" or entry["type"] === "withdrawl" or entry["type"] === "expense"
        # inflation increases value
        set_to_reference(@entries_w, entry["id"], (amount * current_inflation_factor))
      end
    end

    # now update account balnaces
    @entries_w.each do |entry|
      # get values
      amount      = entry["amount"]
      start_month = entry["start_month"]
      end_month   = entry["end_month"]

      # update total for this month
      if start_month <= month and (end_month <= 0 or end_month >= month)
        if entry["type"] === "interest"
          gain = get_reference_amount(@entries_w, entry["reference"])
          gain = gain * (amount/12.0)
          # update reference account for next interest calculation
          deposit_to_reference(@entries_w, entry["reference"], gain)
        end

        if entry["type"] === "income" or entry["type"] === "deposit" or entry["type"] === "payment"
          # update reference account for interest calculation
          deposit_to_reference(@entries_w, entry["reference"], amount)
        end

        if entry["type"] === "expense" or entry["type"] === "withdrawl"
          # update reference account for interest calculation
          withdrawl_from_reference(@entries_w, entry["reference"], amount)
        end
      end
    end
  end

  month = month + 1
end

# init possible month/year display
start_month = Date.today.month
start_year  = Date.today.year
start_month = options.start_month if not options.start_month.nil?
start_year  = options.start_year  if not options.start_year.nil?

# display totals, totals with inflation, and account balances
month = 0
while month < options.months
  month_str = "%4d " % [month] if (options.display_opt & DISOPT_MMYYYY) == DISOPT_NONE
  if (options.display_opt & DISOPT_MMYYYY) == DISOPT_MMYYYY
     total_months = (start_month-1) + month + (12*start_year)
     this_month   = (total_months % 12) + 1
     this_year    = (total_months / 12)
     month_str = "%02d/%04d " % [this_month, this_year]
  end
  total1 = totals_wo[month]
  total2 = totals_w[month]
  total_wo_str = ""
  total_w_str  = ""
  total_wo_str = "\t%.2f" % [total1]       if (options.display_opt & DISOPT_WO_AND_THOUS) == DISOPT_TOTAL_WO_INFL
  total_wo_str = "\t%d"   % [total1/1000]  if (options.display_opt & DISOPT_WO_AND_THOUS) == DISOPT_WO_AND_THOUS
  total_w_str  = "\t%.2f" % [total2]       if (options.display_opt & DISOPT_W__AND_THOUS) == DISOPT_TOTAL_W__INFL
  total_w_str  = "\t%d"   % [total2/1000]  if (options.display_opt & DISOPT_W__AND_THOUS) == DISOPT_W__AND_THOUS
  balances_str = ""
  balances = balances_wo[month]
  balances = balances_w[month] if (options.display_opt & DISOPT_TOTAL_W__INFL) !=  DISOPT_NONE
  balances.each_with_index do |amount, index|
    if amount == 0
      balances_str << "\t%12s" % " "
    elsif account_types[index] === "asset" or account_types[index] === "debt"
      balances_str << "\t%12.2f" % [amount]        if (options.display_opt & DISOPT_IN_THOUSANDS) ===  DISOPT_NONE
      balances_str << "\t%12d"   % [amount/1000]   if (options.display_opt & DISOPT_IN_THOUSANDS) !=   DISOPT_NONE
    else
      balances_str << "\t%12.2f" % [amount]
    end
  end
  puts "%-16s%14s%14s%s" % [month_str, total_wo_str, total_w_str, balances_str]
  month = month + 1
end

