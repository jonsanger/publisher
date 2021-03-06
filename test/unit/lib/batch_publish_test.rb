require 'test_helper'

class BatchPublishTest < ActiveSupport::TestCase
  setup do
    @user = FactoryGirl.create(:user)
    stub_register_published_content
  end

  should "invoke publish on the supplied editions" do
    edition = FactoryGirl.create(:edition, slug: "foo", version_number: 1, state: "ready", body: "x")
    edition_identifiers = [
      { slug: "foo", edition: 1 }
    ]
    BatchPublish.new(edition_identifiers, @user.email).call
    assert_equal "published", edition.reload.state
  end

  context "an edition is already published" do
    should "not try to publish it" do
      edition = FactoryGirl.create(:edition, slug: "foo", version_number: 1, state: "published", body: "x")
      edition.expects(:publish).never
      edition_identifiers = [
        { slug: "foo", edition: 1 }
      ]
      BatchPublish.new(edition_identifiers, @user.email).call
      assert_equal "published", edition.reload.state
    end
  end

  context "notifying Panopticon times out" do
    should "retry 5 times and then continue" do
      edition1 = FactoryGirl.create(:edition, slug: "foo", version_number: 1, state: "ready", body: "x")
      edition2 = FactoryGirl.create(:edition, slug: "bar", version_number: 1, state: "ready", body: "x")
      edition_identifiers = [
        { slug: "foo", edition: 1 },
        { slug: "bar", edition: 1 }
      ]

      stub_request(:put, %r{\A#{PANOPTICON_ENDPOINT}/artefacts/#{edition1.slug}}).to_timeout

      BatchPublish.new(edition_identifiers, @user.email).call
      assert_requested(:put, %r{\A#{PANOPTICON_ENDPOINT}/artefacts/#{edition1.slug}}, times: 6)
      assert_requested(:put, %r{\A#{PANOPTICON_ENDPOINT}/artefacts/#{edition2.slug}}, times: 1)
    end
  end

  context "edition doesn't exist" do
    should "still try to publish the other editions" do
      edition = FactoryGirl.create(:edition, slug: "foo", version_number: 1, state: "ready", body: "x")
      edition_identifiers = [
        { slug: "not-foo", edition: 1 },
        { slug: "foo", edition: 1 }
      ]
      BatchPublish.new(edition_identifiers, @user.email).call
      assert_equal "published", edition.reload.state
    end
  end

  context "an edition is not 'Ready' yet" do
    should "still try to publish the other editions" do
      draft = FactoryGirl.create(:edition, slug: "foo-draft", version_number: 1, state: "draft", body: "x")
      ready = FactoryGirl.create(:edition, slug: "foo", version_number: 1, state: "ready", body: "x")
      draft.expects(:publish).never
      edition_identifiers = [
        { slug: "foo-draft", edition: 1 },
        { slug: "foo", edition: 1 }
      ]
      BatchPublish.new(edition_identifiers, @user.email).call
      assert_equal "draft", draft.reload.state
      assert_equal "published", ready.reload.state
    end
  end

  context "one of the editions cannot be found" do
    should "still try to publish the other editions" do
      edition = FactoryGirl.create(:edition, slug: "foo", version_number: 1, state: "ready", body: "x")
      edition_identifiers = [
        { slug: "not-foo", edition: 1 },
        { slug: "foo", edition: 1 }
      ]
      BatchPublish.new(edition_identifiers, @user.email).call
      assert_equal "published", edition.reload.state
    end
  end
end
