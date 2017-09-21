require 'letsencrypt_plugin/challenge_store'

module LetsencryptPlugin
  class DatabaseStore < ChallengeStore
    def store_content
      ch = LetsencryptPlugin::Challenge.first
      ch = LetsencryptPlugin::Challenge.new if ch.nil?
      ch.response = @content
      ch.save
    end
  end
end
