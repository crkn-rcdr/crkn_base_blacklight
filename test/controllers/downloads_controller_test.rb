require "test_helper"

class DownloadsControllerTest < ActionDispatch::IntegrationTest
  class FakeRedisPool
    def initialize(redis)
      @redis = redis
    end

    def with
      yield @redis
    end
  end

  class FakeRedis
    def initialize(values)
      @values = values
    end

    def get(key)
      @values[key]
    end
  end

  setup do
    @old_pool = DownloadsController.instance_variable_get(:@download_cache_pool)
    @old_secret = Rails.configuration.x.download_token_secret
    @old_endpoint = Rails.configuration.x.download_api_endpoint
    @old_image_base = Rails.configuration.x.iiif_image_base

    Rails.configuration.x.download_token_secret = "test-secret"
    Rails.configuration.x.download_api_endpoint = "https://download.example.test/download"
    Rails.configuration.x.iiif_image_base = "https://image.example.test/iiif/2"
  end

  teardown do
    DownloadsController.download_cache_pool = @old_pool
    Rails.configuration.x.download_token_secret = @old_secret
    Rails.configuration.x.download_api_endpoint = @old_endpoint
    Rails.configuration.x.iiif_image_base = @old_image_base
  end

  test "returns current page download links from Redis cache" do
    cache_key = "download:manifest:69429/m0c824b31w5q"
    set_download_cache(
      cache_key => {
        schema: "crkn-download-cache-v4",
        generated_at: "2026-08-25T18:59:55Z",
        full_pdf_available: true,
        full_pdf_route: {
          repository: "access"
        },
        page_pdf_available: true,
        page_pdf_routes: "aa",
        canvas_noids: [
          "69429/canvas1",
          "69429/canvas2"
        ]
      }.to_json
    )

    get "/dl/oocihm.13566/69429/m0c824b31w5q", params: { pageNum: 2 }

    assert_response :success
    payload = JSON.parse(response.body)

    assert_equal true, payload["cacheHit"]
    assert_equal 2, payload["pageNum"]
    assert_equal 2, payload["pageCount"]
    assert_not payload.key?("canvasDownloadPdfUris")
    assert_not payload.key?("canvasDownloadImgUris")

    full_pdf = URI(payload["docPdfUri"])
    full_pdf_params = Rack::Utils.parse_query(full_pdf.query)
    assert_equal "/download/access/69429/m0c824b31w5q.pdf", full_pdf.path
    assert_equal "oocihm.13566.pdf", full_pdf_params["filename"]
    assert full_pdf_params["sig"].present?

    page_pdf = URI(payload["pagePdfUri"])
    page_pdf_params = Rack::Utils.parse_query(page_pdf.query)
    assert_equal "/download/access/69429/canvas2.pdf", page_pdf.path
    assert_equal "oocihm.13566.2.pdf", page_pdf_params["filename"]
    assert page_pdf_params["sig"].present?

    image = URI(payload["pageImgUri"])
    image_params = Rack::Utils.parse_query(image.query)
    assert_equal "/iiif/2/69429%2Fcanvas2/full/max/0/default.jpg", image.path
    assert_equal 'attachment; filename="oocihm.13566.2.jpg"', image_params["response-content-disposition"]

    page_ocr = URI(payload["pageOcrUri"])
    page_ocr_params = Rack::Utils.parse_query(page_ocr.query)
    assert_equal "/download", page_ocr.path
    assert_equal "oocihm.13566.2", page_ocr_params["slug"]
    assert_equal "69429/canvas2", page_ocr_params["noid"]
    assert_equal "OCR", page_ocr_params["type"]
    expected_page_sig = OpenSSL::HMAC.hexdigest(
      "SHA256",
      "test-secret",
      ["v2", "oocihm.13566.2", "69429/canvas2", "OCR", "", page_ocr_params["expires"]].join("\n")
    )
    assert_equal expected_page_sig, page_ocr_params["sig"]

    doc_ocr = URI(payload["docOcrUri"])
    doc_ocr_pairs = URI.decode_www_form(doc_ocr.query)
    doc_ocr_params = Rack::Utils.parse_query(doc_ocr.query)
    canvas_noids = doc_ocr_pairs.select { |k, _| k == "canvas_noid" }.map(&:last)
    assert_equal "/download", doc_ocr.path
    assert_equal "oocihm.13566", doc_ocr_params["slug"]
    assert_equal "69429/m0c824b31w5q", doc_ocr_params["noid"]
    assert_equal "OCR", doc_ocr_params["type"]
    assert_equal ["69429/canvas1", "69429/canvas2"], canvas_noids
    expected_doc_sig = OpenSSL::HMAC.hexdigest(
      "SHA256",
      "test-secret",
      ["v2", "oocihm.13566", "69429/m0c824b31w5q", "OCR", "69429/canvas1\n69429/canvas2", doc_ocr_params["expires"]].join("\n")
    )
    assert_equal expected_doc_sig, doc_ocr_params["sig"]
  end

  test "omits docOcrUri when canvas count exceeds MAX_DOC_OCR_ZIP_CANVASES while keeping pageOcrUri" do
    cache_key = "download:manifest:69429/m0huge"
    many_canvases = (1..(DownloadsController::MAX_DOC_OCR_ZIP_CANVASES + 1)).map { |i| "69429/c#{i}" }
    set_download_cache(
      cache_key => {
        schema: "crkn-download-cache-v4",
        full_pdf_available: false,
        page_pdf_available: false,
        canvas_noids: many_canvases
      }.to_json
    )

    get "/dl/oocihm.huge/69429/m0huge", params: { pageNum: 1 }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "", payload["docOcrUri"]
    assert_match %r{/download\?.*type=OCR}, payload["pageOcrUri"]
  end

  test "uses per-page PDF routes when present" do
    cache_key = "download:manifest:69429/m0c824b31w5q"
    set_download_cache(
      cache_key => {
        schema: "crkn-download-cache-v4",
        generated_at: "2026-08-25T18:59:55Z",
        full_pdf_available: true,
        full_pdf_route: {
          repository: "access"
        },
        page_pdf_available: false,
        page_pdf_routes: "a0",
        canvas_noids: [
          "69429/canvas1",
          "69429/canvas2"
        ]
      }.to_json
    )

    get "/dl/oocihm.13566/69429/m0c824b31w5q", params: { pageNum: 1 }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_match %r{/download/access/69429/canvas1\.pdf\?}, payload["pagePdfUri"]

    get "/dl/oocihm.13566/69429/m0c824b31w5q", params: { pageNum: 2 }

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "", payload["pagePdfUri"]
    assert_match %r{/iiif/2/69429%2Fcanvas2/full/max/0/default\.jpg\?}, payload["pageImgUri"]
  end

  test "routes canonical downloads through preservation objects" do
    cache_key = "download:manifest:69429/m0legacy"
    set_download_cache(
      cache_key => {
        schema: "crkn-download-cache-v4",
        generated_at: "2026-08-25T18:59:55Z",
        full_pdf_available: true,
        full_pdf_route: {
          repository: "preservation",
          object_path: "aip/oocihm.legacy.pdf"
        },
        page_pdf_available: true,
        page_pdf_routes: "ap0",
        page_pdf_preservation_paths: {
          "2" => "aip/oocihm.legacy.2.pdf"
        },
        canvas_noids: [
          "69429/canvas1",
          "69429/canvas2",
          "69429/canvas3"
        ]
      }.to_json
    )

    get "/dl/oocihm.legacy/69429/m0legacy", params: { pageNum: 2 }

    assert_response :success
    payload = JSON.parse(response.body)

    full_pdf = URI(payload["docPdfUri"])
    full_pdf_params = Rack::Utils.parse_query(full_pdf.query)
    assert_equal "/download/preservation/aip/oocihm.legacy.pdf", full_pdf.path
    assert_nil full_pdf_params["filename"]
    assert full_pdf_params["sig"].present?

    page_pdf = URI(payload["pagePdfUri"])
    page_pdf_params = Rack::Utils.parse_query(page_pdf.query)
    assert_equal "/download/preservation/aip/oocihm.legacy.2.pdf", page_pdf.path
    assert_nil page_pdf_params["filename"]
    assert page_pdf_params["sig"].present?
  end

  test "returns empty download links when cache is missing" do
    set_download_cache({})

    get "/dl/oocihm.13566/69429/m0c824b31w5q", params: { pageNum: 1 }

    assert_response :success
    payload = JSON.parse(response.body)

    assert_equal false, payload["cacheHit"]
    assert_equal "", payload["docPdfUri"]
    assert_equal "", payload["pagePdfUri"]
    assert_equal "", payload["pageImgUri"]
    assert_equal 1, payload["pageNum"]
    assert_equal 0, payload["pageCount"]
  end

  private

  def set_download_cache(values)
    DownloadsController.download_cache_pool = FakeRedisPool.new(FakeRedis.new(values))
  end
end
