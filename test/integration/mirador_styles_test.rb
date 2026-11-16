require 'test_helper'

class MiradorStylesTest < ActionDispatch::IntegrationTest
  test 'embedded workspace fills the viewer instead of overflowing to viewport height' do
    css = Rails.application.assets['application.css'].to_s

    assert css.match?(/#my-mirador\s*>\s*\.fullscreen\s*\{[^}]*height:\s*100%;[^}]*min-height:\s*0[;}]/m),
           'Fullscreen wrapper must fill the embedded viewer without a minimum height'
    assert css.match?(/#my-mirador\s*>\s*\.fullscreen\s*>\s*div\s*\{[^}]*height:\s*100%\s*!important;[^}]*min-height:\s*0[;}]/m),
           'Embedded workspace must use the viewer height instead of the viewport height'
    assert css.match?(/#my-mirador\s*>\s*\.fullscreen-enabled\s*>\s*div\s*\{[^}]*height:\s*100vh\s*!important[;}]/m),
           'Actual fullscreen workspace must retain viewport height'
  end

  test 'mobile viewer has room for the toolbar canvas and navigation' do
    css = Rails.application.assets['application.css'].to_s

    assert css.match?(/#doc-main\s+#my-mirador\s*\{[^}]*min-height:\s*520px\s*!important;[^}]*height:\s*85svh\s*!important;[^}]*max-height:\s*none\s*!important[;}]/m),
           'Mobile viewer must be at least 520px tall without the old 480px cap'
  end

  test 'zoom toolbar is centered within the canvas without clipping its top buttons' do
    css = Rails.application.assets['application.css'].to_s

    assert css.match?(/#my-mirador\s+\.mirador-osd-container\s+\.openseadragon-canvas\s*\+\s*div\s*\{[^}]*top:\s*50%\s*!important;[^}]*bottom:\s*auto\s*!important;[^}]*transform:\s*translateY\(-50%\)\s*!important[;}]/m),
           'Zoom toolbar must be centered within the canvas'
  end
end
