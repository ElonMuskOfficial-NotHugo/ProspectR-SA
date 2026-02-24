require 'prawn'
require 'prawn/table'

class PdfExporter
  BRAND_COLOR  = '1a56db'
  HEADER_COLOR = '1e3a5f'
  ROW_ALT      = 'f0f4ff'
  TEXT_COLOR   = '111827'

  def initialize(businesses, filters: {})
    @businesses = businesses
    @filters    = filters
  end

  def generate
    Prawn::Document.new(page_size: 'A4', page_layout: :landscape, margin: 24) do |pdf|
      draw_header(pdf)
      draw_meta(pdf)
      draw_table(pdf)
      draw_footer(pdf)
    end.render
  end

  private

  def draw_header(pdf)
    pdf.fill_color HEADER_COLOR
    pdf.text "ProspectR SA — Website Prospect Report", size: 18, style: :bold, color: HEADER_COLOR
    pdf.text "Generated: #{Time.current.strftime('%d %B %Y %H:%M')}  |  Total prospects: #{@businesses.size}",
             size: 9, color: '6b7280'
    pdf.move_down 8
    pdf.stroke_color BRAND_COLOR
    pdf.line_width 1.5
    pdf.stroke_horizontal_rule
    pdf.move_down 10
  end

  def draw_meta(pdf)
    return if @filters.blank?
    parts = @filters.reject { |_, v| v.blank? }.map { |k, v| "#{k.to_s.humanize}: #{v}" }
    return if parts.empty?
    pdf.text "Filters — #{parts.join('  |  ')}", size: 8, color: '6b7280'
    pdf.move_down 8
  end

  def draw_table(pdf)
    header = [
      { content: "#",              background_color: HEADER_COLOR, text_color: 'ffffff', font_style: :bold },
      { content: "Business Name",  background_color: HEADER_COLOR, text_color: 'ffffff', font_style: :bold },
      { content: "City",           background_color: HEADER_COLOR, text_color: 'ffffff', font_style: :bold },
      { content: "Category",       background_color: HEADER_COLOR, text_color: 'ffffff', font_style: :bold },
      { content: "Phone",          background_color: HEADER_COLOR, text_color: 'ffffff', font_style: :bold },
      { content: "Website",        background_color: HEADER_COLOR, text_color: 'ffffff', font_style: :bold },
      { content: "Score",          background_color: HEADER_COLOR, text_color: 'ffffff', font_style: :bold },
      { content: "Issues",         background_color: HEADER_COLOR, text_color: 'ffffff', font_style: :bold }
    ]

    rows = @businesses.each_with_index.map do |biz, i|
      audit  = biz.audit_result
      score  = audit&.score || '?'
      issues = audit ? (JSON.parse(audit.issues || '[]') rescue []).join(', ') : 'Not audited'
      url    = biz.website_url.presence || '—'

      bg = (i % 2 == 0) ? 'ffffff' : ROW_ALT

      [
        { content: (i + 1).to_s,    background_color: bg },
        { content: biz.name.to_s,   background_color: bg },
        { content: biz.city.to_s,   background_color: bg },
        { content: biz.category.to_s, background_color: bg },
        { content: biz.phone.to_s,  background_color: bg },
        { content: url,             background_color: bg, text_color: url == '—' ? 'ef4444' : BRAND_COLOR },
        { content: score.to_s,      background_color: bg, font_style: :bold,
          text_color: score_color(score) },
        { content: issues.to_s,     background_color: bg, size: 7 }
      ]
    end

    pdf.table([header] + rows, width: pdf.bounds.width, cell_style: { size: 8, padding: [4, 5] }) do
      column(0).width = 22
      column(1).width = 130
      column(2).width = 70
      column(3).width = 80
      column(4).width = 85
      column(5).width = 120
      column(6).width = 35
    end
  rescue => e
    pdf.text "Error generating table: #{e.message}", color: 'ef4444'
  end

  def draw_footer(pdf)
    pdf.number_pages "ProspectR SA  |  Page <page> of <total>",
                     at: [0, -8], width: pdf.bounds.width,
                     align: :center, size: 7, color: '9ca3af'
  end

  def score_color(score)
    return '6b7280' unless score.is_a?(Integer)
    return 'ef4444' if score >= 70
    return 'f59e0b' if score >= 40
    '10b981'
  end
end
