# frozen_string_literal: true

require "spec_helper"

RSpec.describe SportNotifyBot::MessageFormatter do
  let(:max_length) { 100 }

  before do
    allow(SportNotifyBot).to receive(:configuration).and_return(
      double(max_message_length: max_length)
    )
  end

  describe ".truncate_message" do
    context "when message length is under the limit" do
      let(:message) { "This is a short message" }

      it "returns the original message unchanged" do
        expect(SportNotifyBot::MessageFormatter.truncate_message(message)).to eq(message)
      end
    end

    context "when message length exceeds the limit" do
      let(:long_message) do
        lines = []
        10.times do |i|
          lines << "Line #{i}: " + ("A" * 20)
        end
        lines.join("\n")
      end

      it "truncates the message to respect the max length" do
        result = SportNotifyBot::MessageFormatter.truncate_message(long_message)
        expect(result.bytesize).to be <= max_length
      end

      it "truncates at line boundaries when possible" do
        result = SportNotifyBot::MessageFormatter.truncate_message(long_message)
        expect(result.lines.last).to match(/^Line \d+: A+$/)
      end
    end

    context "when HTML tags need to be balanced after truncation" do
      let(:html_message) do
        [
          "<b>Header 1</b>",
          "Normal line",
          "<b>Header 2 with <i>italic</i> text</b>",
          "<i>Another italic line that might get cut"
        ].join("\n")
      end

      it "balances HTML tags in the truncated message" do
        # Set max_length to cut in the middle of HTML content
        allow(SportNotifyBot).to receive(:configuration).and_return(
          double(max_message_length: html_message.bytesize - 20)
        )

        result = SportNotifyBot::MessageFormatter.truncate_message(html_message)

        # Count opening and closing tags
        open_b = result.scan(/<b>/).length
        close_b = result.scan(/<\/b>/).length
        open_i = result.scan(/<i>/).length
        close_i = result.scan(/<\/i>/).length

        # Tags should be balanced
        expect(open_b).to eq(close_b)
        expect(open_i).to eq(close_i)
      end
    end
  end
end
