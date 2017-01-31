require 'rails_helper'

RSpec.describe Attachment, type: :model do
  describe "Class methods" do
  end
  describe "Scopes" do
    describe "for_me" do
      it "should always work for admin" do
        admin = users(:admin)
        a = Attachment.create(file: File.open('Gemfile'))
        expect(Attachment.for_me(admin)).to include(a)
      end
      it "should always work for admin" do
        admin = users(:admin)
        a = Attachment.create(file: File.open('Gemfile'))
        b = Attachment.create(file: File.open('Gemfile'))
        #ROLES = [:admin, :qkunst, :read_only, :facility_manager, :appraiser]
        a.visibility = [:qkunst,:facility_manager]
        b.visibility = [:read_only]
        a.save
        b.save
        expect(Attachment.for_me(admin)).to include(a)
        expect(Attachment.for_me(admin)).to include(b)
      end
      it "should always work correctly for readonly" do
        admin = users(:read_only_user)
        a = Attachment.create(file: File.open('Gemfile'))
        b = Attachment.create(file: File.open('Gemfile'))
        a.visibility = [:qkunst,:facility_manager]
        b.visibility = [:read_only]
        a.save
        b.save
        expect(Attachment.for_me(admin)).not_to include(a)
        expect(Attachment.for_me(admin)).to include(b)
      end
    end
  end
end