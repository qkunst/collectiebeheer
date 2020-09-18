# frozen_string_literal: true

class CollectionDownloadWorker
  include Sidekiq::Worker

  sidekiq_options retry: false, backtrace: true, queue: :qkunst_often

  def perform(collection_id, requested_by_user_id, format = :xlsx, audience = :default, fields_to_expose = [:id, :title_rendered])
    format = format.to_sym
    audience = audience.to_sym
    fields_to_expose = fields_to_expose.map(&:to_sym)

    collection = Collection.find(collection_id)

    works = collection.works_including_child_works.audience(audience).preload_relations_for_display(:complete)

    if format.to_sym == :xlsx
      workbook = works.to_workbook(fields_to_expose, collection)
      filename = workbook.write_to_xlsx(Rails.root.join("tmp", "#{SecureRandom.uuid}.xlsx"))

      Message.create(to_user_id: requested_by_user_id, from_user_name: "Download voorbereider", attachment: File.open(filename), message: "De download is gereed, open het bericht in je browser om de bijlage te downloaden.\n\nFormaat: #{format}  \nDoelgroep: #{audience}  \nVelden: #{fields_to_expose.map { |f| "“#{f}”"}.to_sentence}", subject: "Download #{collection.name} gereed")
    end
  end
end
