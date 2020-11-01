require 'rubygems'
require 'bundler/setup'
require_relative 'helpers/name_helper'
extend NameHelper

require 'erb'
require 'discordrb'
require 'discordrb/webhooks'
require 'base64'
require 'net/http'
require 'uri'
require 'date'
require 'active_record'
require 'yaml'
require 'require_all'
require 'pp'
require_all 'models/*.rb'

env = ENV['ENVIRONMENT'] || 'default'
db_config = YAML::load(ERB.new(File.read('config/database.yml')).result)[env]
ActiveRecord::Base.establish_connection(db_config)

bot = Discordrb::Bot.new token: ENV['BOT_TOKEN'], log_mode: :debug

bot.message(start_with: 'randping') do |event|
  loser = event.server.members.sample
  event.respond(loser.mention)
end

bot.message(start_with: Regexp.new(Regexp.escape('now this is where the fun begins'), Regexp::IGNORECASE)) do |event|
  server = Server.find_or_create_by(discord_id: event.server.id)
  if server.crywalker
    event.respond('Anakin Crywalker')
  else
    server.update(crywalker: true)
    while(server.crywalker)
      event.respond('Anakin Crywalker')
      sleep(3600)
    end
  end
end

bot.message(start_with: Regexp.new(Regexp.escape('I have the high ground'), Regexp::IGNORECASE)) do |event|
  server = Server.find_or_create_by(discord_id: event.server.id)
  event.respond("you underestimate my power!")
  if server.crywalker
    server.update(crywalker: false)
  else
    event.respond('**observation:** *Crywalker sequence was not running*')
  end
end

bot.message(start_with: ']quote') do |event|
  return if event.author.bot_account?
  member = event.message.mentions[0].on(event.server) || event.author
  say = event.message.content.split(/<@!?\d*>/, 2).last.gsub('@everyone', '@еvеryonе')
  avatar = "data:image/png;base64,#{Base64.encode64(Net::HTTP.get URI(member.avatar_url.gsub('webp', 'png')))}"
  hook = event.message.channel.create_webhook(member.nick || member.name, avatar)
  client = Discordrb::Webhooks::Client.new(token: hook.token, id: hook.id)
  client.execute do |builder|
    builder.content = say
  end
  hook.delete
end

bot.message(start_with: ']sneakquote') do |event|
  return if event.author.bot_account?
  member = event.message.mentions[0].on(event.server) || event.author
  say = event.message.content.split(/<@!?\d*>/, 2).last.gsub('@everyone', '@еvеryonе')
  avatar = "data:image/png;base64,#{Base64.encode64(Net::HTTP.get URI(member.avatar_url.gsub('webp', 'png')))}"
  hook = event.message.channel.create_webhook(member.nick || member.name, avatar)
  event.message.delete

  client = Discordrb::Webhooks::Client.new(token: hook.token, id: hook.id)
  client.execute do |builder|
    builder.content = say
  end
  hook.delete
end

bot.message(with_text: /I don('|‘|’|´|`)t like sand/i) do |event|
  server = Server.find_or_create_by(discord_id: event.server.id)
  if server.sandstorm_mode
    bot_profile = bot.profile.on(event.server)
    event.server.text_channels.each do |channel|
      begin
        if bot_profile.permission?(:send_messages, channel)
          channel.send_message('It\'s coarse and rough and irritating and it gets everywhere.')
          sleep(1)
        end
      rescue Discordrb::Errors::NoPermission
        #TODO error tratment
      end
    end
  else
    event.respond('It\'s coarse and rough and irritating and it gets everywhere.')
  end
end

bot.message(start_with: /]sandstorm/i) do |event|
  server = Server.find_or_create_by(discord_id: event.server.id)
  if event.author.defined_permission?(:administrator)
    if event.message.content.match?(/.* enable/i)
      if server.sandstorm_mode
        event.respond("sandstorm mode already active")
      else
        server.update(sandstorm_mode: true)
        event.respond("sandstorm mode activated use it with care")
      end
    elsif event.message.content.match?(/.* disable/i)
      if server.sandstorm_mode
        server.update(sandstorm_mode: false)
        event.respond("sandstorm mode deactivated")
      else
        event.respond("sandstorm mode isn't active")
      end
    end
  else
    event.respond("user lacks permissions")
  end
end

bot.message(start_with: /]penis.mode/i) do |event|
  server = Server.find_or_create_by(discord_id: event.server.id)
  if event.author.defined_permission?(:administrator)
    if event.message.content.match?(/.* enable/i)
      if server.penis_mode
        event.respond("penis mode already active")
      else
        server.update(penis_mode: true)
        event.respond("penis mode activated")
      end
    elsif event.message.content.match?(/.* disable/i)
      if server.penis_mode
        server.update(penis_mode: false)
        event.respond("penis mode deactivated")
      else
        event.respond("penis mode isn't active")
      end
    end
  else
    event.respond("user lacks permissions")
  end
end

MONTHS = {
  "October" => "💀"
}

bot.message(with_text: /.*penis.*/i) do |event|
  server = Server.find_or_create_by(discord_id: event.server.id)
  return unless server.penis_mode
  seasonal_flavor = MONTHS[Date.today.strftime("%B")]
  event.author.set_nick("#{seasonal_flavor}Penis#{seasonal_flavor}") rescue nil
  event.respond("Penis")
end

bot.message(with_text: /]member list/i) do |event|
  list = event.server.members.map(&:name)
  event.respond list.join('\n')
end

bot.message(start_with: /]rename.mode/i) do |event|
  server = Server.find_or_create_by(discord_id: event.server.id)
  if event.author.defined_permission?(:administrator)
    if event.message.content.match?(/.* enable, .*/i)
      new_name = event.message.content.split(', ').last
      server.nick = new_name
      if server.rename_mode
        event.respond("rename mode already enabled, setting new rename name to #{new_name}")
      else
        server.rename_mode = true
        server.save
        event.respond("rename mode enabled renaming everyone I can to #{new_name}\n this will take some time because of discord's rate limitations")
        event.server.members.each_slice(5) do |group|
          break unless server.rename_mode
          group.each do |member|
            member.set_nick(new_name(server.nick, member)) rescue nil
          end
          sleep(1)
        end
      end
    elsif event.message.content.match?(/.* run, .*/i)
      new_name = event.message.content.split(', ').last
      server.nick = new_name
      server.save
      event.respond("single run rename called, renaming everyone I can to #{new_name}\n this will take some time because of discord's rate limitations")
      puts event.server.members
      event.server.members.each_slice(3) do |group|
        puts "AEIOU"
        puts group
        group.each do |member|
          puts member.name
          member.set_nick(new_name(server.nick, member)) rescue nil
        end
        sleep(1)
      end
    elsif event.message.content.match?(/.* disable/i)
      if server.rename_mode
        server.update(rename_mode: false)
        event.respond("rename mode disabled")
      else
        event.respond("rename mode already disabled")
      end
    else
      event.respond("rename mode syntax:\n `rename mode enable, <name you want>` to enable\n `rename mode run, <name you want>` to just rename everyone once and stop\n `rename mode disable` to disable")
    end
  else
    event.respond("user lacks permissions")
  end
end

bot.member_join() do |event|
  server = Server.find_or_create_by(discord_id: event.server.id)
  if server.rename_mode
    member = event.user.on(event.server)
    member.set_nick(new_name(server.nick, member)) rescue nil
  end
end

bot.member_update() do |event|
  server = Server.find_or_create_by(discord_id: event.server.id)
  if server.rename_mode
    member = event.user.on(event.server)
    member.set_nick(new_name(server.nick, member)) rescue nil
  end
end


bot.message(start_with: /]role count/i) do |event|
    role_name = event.message.content.gsub(/]role count /i, '')

      role = event.message.role_mentions[0] || event.server.roles.find{|role| role.name.downcase == role_name.downcase.strip}
        event.respond("#{role.name} has #{role.members.count} members")
end

bot.run
