require 'active_support/core_ext/integer/inflections'

Time::DATE_FORMATS.merge!(
  default: ->(time) { time.to_s(:date) + ', ' + time.to_s(:time) },
  date: ->(time) { time.to_date.to_s },
  time: ->(time) { time.strftime("#{(t = time.hour % 12) == 0 ? 12 : t}:%M#{time.strftime('%p').downcase}") }
)

Date::DATE_FORMATS.merge!(
  default: ->(date) { date.strftime("%a #{date.day.ordinalize} %b %Y") },
  post: ->(date) { date.strftime("#{date.day} %b#{" #{date.year}" unless date.year == Date.today.year}") }
)
