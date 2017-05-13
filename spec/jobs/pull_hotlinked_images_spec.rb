require 'rails_helper'
require 'jobs/regular/pull_hotlinked_images'

describe Jobs::PullHotlinkedImages do

  before do
    png = Base64.decode64("R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw==")
    stub_request(:get, "http://wiki.mozilla.org/images/2/2e/Longcat1.png").to_return(body: png)
    SiteSetting.download_remote_images_to_local = true
    FastImage.expects(:size).returns([100, 100]).at_least_once
  end

  it 'replaces image src' do
    post = Fabricate(:post, raw: "<img src='http://wiki.mozilla.org/images/2/2e/Longcat1.png'>")

    Jobs::PullHotlinkedImages.new.execute(post_id: post.id)
    post.reload

    expect(post.raw).to match(/^<img src='\/uploads/)
  end

  it 'replaces image src without protocol' do
    post = Fabricate(:post, raw: "<img src='//wiki.mozilla.org/images/2/2e/Longcat1.png'>")

    Jobs::PullHotlinkedImages.new.execute(post_id: post.id)
    post.reload

    expect(post.raw).to match(/^<img src='\/uploads/)
  end

  describe 'onebox' do

    class Onebox::Engine::WhitelistedGenericOnebox
      def data
        @data ||= begin
          d = { link: link }.merge(raw)

          d[:title] = "Longcat1"
          d[:description] = "About Longcat1 in Mozilla's wiki article"
          d[:domain] = "wiki.mozilla.org"
          d[:image] = "http://wiki.mozilla.org/images/2/2e/Longcat1.png"

          d
        end
      end
    end

    let(:url) { "http://nytimes.com/about-longcat1" }

    before do
      stub_request(:get, url).to_return(body: "{title: 'hello'}")
    end

    it 'replaces image src' do
      post = Fabricate(:post, raw: "#{url}")

      Jobs::PullHotlinkedImages.new.execute(post_id: post.id)
      post.reload

      expect(post.cooked).to match(/^<img src='\/uploads/)
    end

  end

end
