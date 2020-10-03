module NameHelper

  def new_name(name, member)
    name.gsub('{name}', member.name)
      .gsub('{nick}', member.nick || member.name)
  end

end