# frozen_string_literal: true

class PdfPrinterWorker
  include Sidekiq::Worker

  sidekiq_options retry: true, backtrace: true, queue: :qkunst_default

  def perform(url, options = {})
    inform_user_id = options[:inform_user_id] || options["inform_user_id"]
    subject_object_id = options[:subject_object_id] || options["subject_object_id"]
    subject_object_type = options[:subject_object_type] || options["subject_object_type"]

    filename = "/tmp/#{SecureRandom.base58(32)}.pdf"

    # urls are recognized as urls, but local files are not; simple trick that works on unixy systems
    grover_resource = if (url.match(/\A\/[A-Za-z]*\//))
      File.read(url)
    # only trust our own content
    elsif url.match(/\Ahttps:\/\/collectiemanagement\.qkunst\.nl/)
      url
    else
      raise "Unsecure location (#{url})"
    end

    Grover.new(grover_resource,
      format: "A4",
      path: filename,
      emulate_media: :print,
      launch_args: ['--font-render-hinting=none'],
      printBackground: true
    ).to_pdf

    if inform_user_id
      Message.create(to_user_id: inform_user_id, subject_object_id: subject_object_id, subject_object_id: subject_object_type, from_user_name: "Download voorbereider", attachment: File.open(filename), message: "De download is gereed, open het bericht in je browser om de bijlage te downloaden.\n\nFormaat: PDF", subject: "PDF gereed")
    end

    return filename
  end
end
