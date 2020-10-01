require 'rubygems'
require 'bundler/setup'

require 'discordrb'
require 'discordrb/webhooks'
require 'base64'
require 'net/http'
require 'uri'

bot = Discordrb::Bot.new token: ENV['BOT_TOKEN']

crywalker = []
bot.message(start_with: 'randping') do |event|
  loser = event.server.members.sample
  event.respond(loser.mention)
end

bot.message(start_with: Regexp.new(Regexp.escape('now this is where the fun begins'), Regexp::IGNORECASE)) do |event|
  if crywalker.include?(event.server)
    event.respond('Anakin Crywalker')
  else
    crywalker += [event.server]
    while(crywalker.include?(event.server))
      event.respond('Anakin Crywalker')
      sleep(3600)
    end
  end
end

bot.message(start_with: Regexp.new(Regexp.escape('I have the high ground'), Regexp::IGNORECASE)) do |event|
  event.respond("you underestimate my power!")
  if crywalker.include?(event.server)
    crywalker -= [event.server]
  else
    event.respond('**observation:** *Crywalker sequence was not running*')
  end
end

bot.message(start_with: ']quote') do |event|
  return if event.author.bot_account?
  puts event.message.content
  member = event.message.mentions[0].on(event.server) || event.author
  say = event.message.content.split(/<@!?\d*>/, 2).last
  avatar = "data:image/png;base64,#{Base64.encode64(Net::HTTP.get URI(member.avatar_url.gsub('webp', 'png')))}"
  hook = event.message.channel.create_webhook(member.nick || member.name, avatar)

  client = Discordrb::Webhooks::Client.new(token: hook.token, id: hook.id)
  client.execute do |builder|
    builder.content = say
  end
  hook.delete
end

sandstorm_active = []

bot.message(with_text: /I don('|‘|’|´|`)t like sand/i) do |event|
  if sandstorm_active.include?(event.server)
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
  if event.author.defined_permission?(:administrator)
    if event.message.content.match?(/.* enable/i)
      if sandstorm_active.include?(event.server)
        event.respond("sandstorm mode already active")
      else
        sandstorm_active << event.server
        event.respond("sandstorm mode activated use it with care")
      end
    elsif event.message.content.match?(/.* disable/i)
      if sandstorm_active.include?(event.server)
        sandstorm_active -= [event.server]
        event.respond("sandstorm mode deactivated")
      else
        event.respond("sandstorm mode isn't active")
      end
    end
  else
    event.respond("user lacks permissions")
  end
end

penis_active = []

bot.message(start_with: /]penis.mode/i) do |event|
  if event.author.defined_permission?(:administrator)
    if event.message.content.match?(/.* enable/i)
      if penis_active.include?(event.server)
        event.respond("penis mode already active")
      else
        penis_active << event.server
        event.respond("penis mode activated")
      end
    elsif event.message.content.match?(/.* disable/i)
      if penis_active.include?(event.server)
        penis_active -= [event.server]
        event.respond("penis mode deactivated")
      else
        event.respond("penis mode isn't active")
      end
    end
  else
    event.respond("user lacks permissions")
  end
end

bot.message(with_text: /.*penis.*/i) do |event|
  return unless penis_active.include?(event.server)
  event.author.set_nick("Penis") rescue nil
  event.respond("Penis")
end

rename_mode = Hash.new({name: nil, active: false})

bot.message(start_with: /]rename.mode/i) do |event|
  if event.author.defined_permission?(:administrator)
    if event.message.content.match?(/.* enable, .*/i)
      new_name = event.message.content.split(', ').last
      rename_mode[event.server][:name] = new_name
      if(rename_mode[event.server][:active])
        event.respond("rename mode already enabled, setting new rename name to #{new_name}")
      else
        rename_mode[event.server][:active] = true
        event.respond("rename mode enabled renaming everyone I can to #{new_name}\n this will take some time because of discord's rate limitations")
        event.server.members.each do |member|
          member.set_nick(rename_mode[event.server][:name]) rescue nil
          sleep(1)
        end
      end
    elsif event.message.content.match?(/.* run, .*/i)
      new_name = event.message.content.split(', ').last
      rename_mode[event.server][:name] = new_name
      if(rename_mode[event.server][:active])
        event.respond("rename mode already enabled, setting new rename name to #{new_name}")
      else
        event.respond("single run rename called, renaming everyone I can to #{new_name}\n this will take some time because of discord's rate limitations")
        event.server.members.each do |member|
          member.set_nick(rename_mode[event.server][:name]) rescue nil
          sleep(1)
        end
      end
    elsif event.message.content.match?(/.* disable/i)
      rename_mode[event.server][:active] = false
      event.respond("rename mode disabled")
    else
      event.respond("rename mode syntax:\n `rename mode enable, <name you want>` to enable\n `rename mode run, <name you want>` to just rename everyone once and stop\n `rename mode disable` to disable")
    end
  else
    event.respond("user lacks permissions")
  end
end

bot.member_join() do |event|
  if(rename_mode[event.server][:active])
    event.user.set_nick(rename_mode[event.server][:name]) rescue nil
  end
end

bot.member_update() do |event|
  if(rename_mode[event.server][:active])
    event.user.set_nick(rename_mode[event.server][:name]) rescue nil
  end
end

bot.run
