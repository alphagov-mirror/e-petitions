require 'rails_helper'

RSpec.describe Archived::AnonymizePetitionJob, type: :job do
  let(:timestamp) { "2018-12-31T00:00:00Z".in_time_zone }
  let!(:petition) { FactoryBot.create(:archived_petition, :closed, sponsors_signed: true, closed_at: "2018-06-30T00:00:00Z") }

  it "marks every signature as archived" do
    expect {
      described_class.perform_now(petition, timestamp.iso8601)
    }.to change {
      petition.signatures.not_anonymized.count
    }.from(6).to(0)
  end

  it "schedules a new job if it doesn't finish archiving" do
    expect {
      described_class.perform_now(petition, timestamp.iso8601, limit: 2)
    }.to have_enqueued_job(described_class).with(petition, timestamp.iso8601, limit: 2)
  end

  it "marks the petition as anonymized if it finishes archiving" do
    expect {
      described_class.perform_now(petition, timestamp.iso8601)
    }.to change {
      petition.anonymized_at
    }.from(nil).to(timestamp)
  end

  shared_examples_for "anonymization" do
    it "anonymizes the signature" do
      expect {
        perform_enqueued_jobs {
          described_class.perform_later(petition, timestamp.iso8601)
        }
      }.to change {
        signature.reload.anonymized_at
      }.from(nil).to(timestamp)
    end

    it "marks the petition as anonymized" do
      expect {
        perform_enqueued_jobs {
          described_class.perform_later(petition, timestamp.iso8601)
        }
      }.to change {
        petition.reload.anonymized_at
      }.from(nil).to(timestamp)
    end
  end

  context "with a pending signature" do
    let!(:signature) { FactoryBot.create(:archived_signature, :pending, created_at: created_at, petition: petition) }

    context "when it was created at the beginning" do
      let(:created_at) { "2018-01-01T12:00:00Z" }

      it_behaves_like "anonymization"
    end

    context "when it was created at the end" do
      let(:created_at) { "2018-06-29T12:00:00Z" }

      it_behaves_like "anonymization"
    end
  end

  context "with a validated signature" do
    let!(:signature) { FactoryBot.create(:archived_signature, :validated, created_at: created_at, petition: petition) }

    context "when it was created at the beginning" do
      let(:created_at) { "2018-01-01T12:00:00Z" }

      it_behaves_like "anonymization"
    end

    context "when it was created at the end" do
      let(:created_at) { "2018-06-29T12:00:00Z" }

      it_behaves_like "anonymization"
    end
  end

  context "with a fraudulent signature" do
    let!(:signature) { FactoryBot.create(:archived_signature, :fraudulent, created_at: created_at, petition: petition) }

    context "when it was created at the beginning" do
      let(:created_at) { "2018-01-01T12:00:00Z" }

      it_behaves_like "anonymization"
    end

    context "when it was created at the end" do
      let(:created_at) { "2018-06-29T12:00:00Z" }

      it_behaves_like "anonymization"
    end
  end

  context "with an invalidated signature" do
    let!(:signature) { FactoryBot.create(:archived_signature, :invalidated, created_at: created_at, petition: petition) }

    context "when it was created at the beginning" do
      let(:created_at) { "2018-01-01T12:00:00Z" }

      it_behaves_like "anonymization"
    end

    context "when it was created at the end" do
      let(:created_at) { "2018-06-29T12:00:00Z" }

      it_behaves_like "anonymization"
    end
  end

  context "with an invalid signature" do
    let!(:signature) { FactoryBot.create(:archived_signature, :pending, created_at: "2018-01-01T12:00:00Z", petition: petition) }

    before do
      signature.update_column(:location_code, nil)
    end

    it "notifies Appsignal" do
      expect(Appsignal).to receive(:send_exception).with(an_instance_of(ActiveRecord::RecordInvalid))

      perform_enqueued_jobs {
        described_class.perform_later(petition, timestamp.iso8601)
      }
    end
  end
end
