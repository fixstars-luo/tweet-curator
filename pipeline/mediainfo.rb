# share links to media to slack channel

require "time"

require_relative "../lib/slack_util"

# @param tweets [Array<Hash>] tweets to process
# @param slack_webhook [SlackUtil::Webhook] Slack webhook URL
def mediainfo_pipeline(tweets, slack_webhook:)
  # traverse from old ones
  tweets.reverse.each do |tweet|
    info = Mediainfo.new(tweet)
    next unless info.mediainfo?

    attachments = [gen_twitter_attachment(tweet)]

    slack_webhook.post({
      text: "*#{info.types.join(", ")}*",
      attachments: attachments,
    })

    info.links.each do |link|
      slack_webhook.post({
        text: link,
        unfurl_links: true,
      })
    end
  end
end

def gen_twitter_attachment(tweet)
  attrs = tweet[:attrs].fetch(:retweeted_status, tweet[:attrs])

  gen_name = Proc.new do |attrs|
    "#{attrs[:user][:name]} (@#{attrs[:user][:screen_name]}) #{attrs[:user][:protected] ? "🔒" : ""}"
  end

  attachment = {
    author_name: gen_name.call(attrs),
    author_link: tweet[:url],
    author_icon: attrs[:user][:profile_image_url_https],
    color: "#00acee",
    text: attrs[:text],
    ts: Time.parse(attrs[:created_at]).to_i,
  }
  if tweet[:attrs][:retweeted_status]
    attachment[:footer] = "Retweeted by #{gen_name.call(tweet[:attrs])}"
    attachment[:footer_icon] = tweet[:attrs][:user][:profile_image_url_https]
  end
  if attrs[:entities][:media]
    attachment[:thumb_url] = attrs[:entities][:media].first[:media_url_https]
  end
  attachment
end

class Mediainfo
  attr_reader :types, :links

  # @param tweet [Hash] hased tweet data
  def initialize(tweet)
    @types = []
    @links = []

    p tweet

    @types << "Now playing" if /nowplaying/i =~ tweet[:attrs][:text]

    urls = tweet[:attrs][:entities][:urls].uniq { |url| url[:expanded_url] }
    urls.each do |url|
      case URI.parse(url[:expanded_url]).host
      when "song.link", "album.link"
        @types << "Odesli"
        @links << url[:url]
      when "youtube.com", "youtu.be"
        @types << "Youtube"
        @links << url[:url]
      when "music.apple.com"
        @types << "Apple Music"
        @links << url[:url]
      when "open.spotify.com"
        @types << "Spotify"
        @links << url[:url]
      end
    end
  end

  def mediainfo?; !@types.empty?; end
end