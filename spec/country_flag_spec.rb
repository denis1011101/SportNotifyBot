# frozen_string_literal: true

require "spec_helper"

RSpec.describe SportNotifyBot::CountryFlag do # rubocop:disable Metrics/BlockLength
  describe ".for" do
    it "converts english country name" do
      expect(described_class.for("France")).to eq("\u{1F1EB}\u{1F1F7}")
    end

    it "converts russian country name" do
      expect(described_class.for("Россия")).to eq("\u{1F1F7}\u{1F1FA}")
    end

    it "is case and whitespace insensitive" do
      expect(described_class.for("  хорватия ")).to eq("\u{1F1ED}\u{1F1F7}")
    end

    it "returns subdivision flag for England" do
      expect(described_class.for("Англия")).to eq("\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}")
    end

    it "returns nil for supranational entities" do
      expect(described_class.for("Европа")).to be_nil
      expect(described_class.for("World")).to be_nil
    end

    it "returns nil for unknown country" do
      expect(described_class.for("Атлантида")).to be_nil
    end

    it "returns nil for blank input" do
      expect(described_class.for("")).to be_nil
      expect(described_class.for(nil)).to be_nil
    end
  end

  describe ".from_iso" do
    it "builds regional indicator pair" do
      expect(described_class.from_iso("US")).to eq("\u{1F1FA}\u{1F1F8}")
    end
  end
end
