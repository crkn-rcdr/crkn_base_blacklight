class DownloadToolbarComponent < ViewComponent::Base
  attr_reader :document, :page_num

  def initialize(document:, page_num: 1)
    @document = document
    @page_num = page_num.to_i.positive? ? page_num.to_i : 1
  end

  def doc_id
    @document._source['id'] || @document['id']
  end

  def ark_path
    raw_ark = @document._source['ark'] || @document['ark']
    raw_ark.to_s.sub(%r{\Ahttps?://n2t\.net/ark:/}i, '').sub(%r{\Aark:/}i, '')
  end

  def download_data
    @download_data ||= DownloadsController.download_data_for(doc_id, ark_path, @page_num) rescue {}
  end

  def doc_pdf_uri
    download_data['docPdfUri'].presence
  end

  def page_pdf_uri
    download_data['pagePdfUri'].presence
  end

  def page_img_uri
    download_data['pageImgUri'].presence
  end

  def any_available?
    doc_pdf_uri.present? || page_pdf_uri.present? || page_img_uri.present?
  end
end
