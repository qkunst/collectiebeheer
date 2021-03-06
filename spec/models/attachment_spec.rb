# frozen_string_literal: true

require "rails_helper"

RSpec.describe Attachment, type: :model do
  describe "Scopes" do
    describe ".without_works" do
      it "should return attachments without works" do
        expect(Attachment.without_works).to include(attachments(:collection_attachment))
        expect(Attachment.without_works).not_to include(attachments(:work_attachment))
      end
    end
    describe ".without_artists" do
      it "should return attachments without works" do
        expect(Attachment.without_artists).to include(attachments(:collection_attachment))
        expect(Attachment.without_artists).not_to include(attachments(:artist_attachment))
        expect(Attachment.without_artists).to include(attachments(:work_attachment))
      end

      it "should only return attache less when combined with .without_works" do
        expect(Attachment.without_artists.without_works).to include(attachments(:collection_attachment))
        expect(Attachment.without_artists.without_works).not_to include(attachments(:artist_attachment))
        expect(Attachment.without_artists.without_works).not_to include(attachments(:work_attachment))
      end
    end
    describe "for_role" do
      let(:admin_only_attachment) { works(:work1).attachments.create(file: File.open("Gemfile"), collection: works(:work1).collection) }
      let(:all_roles_attachment) { works(:work1).attachments.create(file: File.open("Gemfile"), collection: works(:work1).collection, visibility: [:compliance, :facility_manager, :appraiser, :qkunst]) }

      before do
        admin_only_attachment
        all_roles_attachment
      end

      [:advisor, :admin].each do |role|
        it "should return all for #{role}" do
          expect(Attachment.for_role(role)).to include(admin_only_attachment)
          expect(Attachment.for_role(role)).to include(all_roles_attachment)
        end
      end
      [:compliance, :facility_manager, :appraiser, :qkunst].each do |role|
        it "should filter #{role}" do
          expect(Attachment.for_role(role)).not_to include(admin_only_attachment)
          expect(Attachment.for_role(role)).to include(all_roles_attachment)
        end
      end
      [:readonly].each do |role|
        it "should show none for #{role}" do
          expect(Attachment.for_role(role)).not_to include(admin_only_attachment)
          expect(Attachment.for_role(role)).not_to include(all_roles_attachment)
        end
      end
    end
    describe "for_me" do
      it "should always work for admin" do
        admin = users(:admin)
        a = works(:work1).attachments.create(file: File.open("Gemfile"), collection: works(:work1).collection)
        expect(Attachment.for_me(admin)).to include(a)
      end
      it "should always work for admin" do
        admin = users(:admin)
        a = works(:work1).attachments.create(file: File.open("Gemfile"), collection: works(:work1).collection)
        b = works(:work1).attachments.create(file: File.open("Gemfile"), collection: works(:work1).collection)
        # ROLES = [:admin, :qkunst, :read_only, :facility_manager, :appraiser]
        a.visibility = [:qkunst, :facility_manager]
        b.visibility = [:read_only]
        a.save
        b.save
        expect(Attachment.for_me(admin)).to include(a)
        expect(Attachment.for_me(admin)).to include(b)
      end
      it "should always work correctly for readonly" do
        admin = users(:read_only)
        a = works(:work1).attachments.create(file: File.open("Gemfile"), collection: works(:work1).collection)
        b = works(:work1).attachments.create(file: File.open("Gemfile"), collection: works(:work1).collection)
        a.visibility = [:qkunst, :facility_manager]
        b.visibility = [:read_only]
        a.save
        b.save
        expect(Attachment.for_me(admin)).not_to include(a)
        expect(Attachment.for_me(admin)).to include(b)
      end
    end
  end
end
