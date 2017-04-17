class MonthlyReportService
  NAME_COLUMN_WIDTH = 40
  ONE_SIGN_DAY_COLUMN_WIDTH = 2
  TWO_SIGN_DAY_COLUMN_WIDTH = 3
  TOTAL_COLUMN_WIDTH = 12

  def initialize(date)
    @date = date
    @users = User.order(:name)
    menus = Menu.in_date_range(@date.beginning_of_month, @date.end_of_month).order(:date)
    @user_menus = UserMenu.joins(:menu).where(menu: menus, neem: false)
      .pluck(:'menus.date', :'user_id')
  end

  class << self
    def export(date)
      instance = new(date)
      instance.export_to_xlsx_stream
    end

    def filename(date)
      "monthly_report_#{date.month}_#{date.year}.xlsx"
    end

    def type
      'application/vnd.ms-excel'
    end
  end

  def export_to_xlsx_stream
    package = Axlsx::Package.new
    workbook = package.workbook

    workbook_styles = {}
    styles.each { |name, style| workbook_styles[name] = workbook.styles.add_style(style) }

    workbook.add_worksheet(name: report_date(@date)) do |sheet|
      last_cell = report_width - 1

      sheet.add_row(report_title, style: workbook_styles[:title])
      sheet.merge_cells(sheet.rows.last.cells[(0..last_cell)])
      sheet.add_row(report_upload_date, style: workbook_styles[:uploaded])
      sheet.add_row()

      sheet.add_row(report_table_header, style: table_header_styles.map { |style| workbook_styles[style] })
      @users.each { |user| sheet.add_row(report_table_user_info(user), style: table_user_styles.map { |style| workbook_styles[style] }) }

      sheet.add_row(report_table_total, style: total_styles.map { |style| workbook_styles[style] })

      sheet.column_widths *column_widths
    end

    package.to_stream.read
  end

  private

  def styles
    {
      title: {
        font_name: 'Arial',
        sz: 22,
        b: true,
        alignment: { horizontal: :center }
      },
      uploaded: {
        font_name: 'Arial',
        sz: 9,
        b: false
      },
      header: {
        border: { color: 'FF000000', style: :medium },
        font_name: 'Arial',
        sz: 11,
        b: true,
        alignment: { horizontal: :center }
      },
      header_weekend: {
        border: { color: 'FF000000', style: :medium },
        font_name: 'Arial',
        sz: 11,
        b: true,
        alignment: { horizontal: :center },
        bg_color: '00ea829f'
      },
      name_cell: {
        border: { color: 'FF000000', style: :thin },
        font_name: 'Arial',
        sz: 11,
        b: false,
        alignment: { horizontal: :left }
      },
      default_cell: {
        border: { color: 'FF000000', style: :thin },
        font_name: 'Arial',
        sz: 11,
        b: false,
        alignment: { horizontal: :center }
      },
      weekend_cell: {
        border: { color: 'FF000000', style: :thin },
        font_name: 'Arial',
        sz: 11,
        b: false,
        alignment: { horizontal: :center },
        bg_color: '00ea829f'
      },
      bold_cell: {
        border: { color: 'FF000000', style: :thin },
        font_name: 'Arial',
        sz: 11,
        b: true,
        alignment: { horizontal: :center }
      },
      total: {
        border: { color: 'FF000000', style: :thin },
        font_name: 'Arial',
        sz: 11,
        b: true,
        alignment: { horizontal: :right }
      }
    }
  end

  def translate(key)
    I18n.t('monthly_report.' + key)
  end

  def month_translate(month_number)
    date = Date.current(month: month_number)
    I18n.l(date, format: :report_month)
  end

  def date_by_day(date, day)
    date.change(day: day.to_i)
  end

  def all_days_in_month(date)
    (1..Time.days_in_month(date.month, date.year)).to_a.map(&:to_s)
  end

  def report_date(date)
    I18n.l(date, format: :monthly_report_date)
  end

  def report_title
    title = [report_date(@date)]
    width = report_width - 1
    width.times { title << nil }
    title
  end

  def report_upload_date
    [translate('upload_date') + ' ' + I18n.l(Date.current)]
  end

  def report_table_total
    total = [translate('total')]
    width = report_width - 2
    width.times { total << nil }
    total << "#{@user_menus.size}"
  end

  def report_table_header
    header = [translate('name')]
    header += all_days_in_month(@date)
    header << translate('sum')
  end

  def report_table_user_info(user)
    user_row = [user.name]

    total = 0
    all_days_in_month(@date).each do |day|
      date = date_by_day(@date, day)
      if @user_menus.include?([date, user.id])
        user_row << 1
        total += 1
      else
        user_row << nil
      end
    end

    user_row << total
  end

  def calendar_styles(weekend, work)
    all_days_in_month(@date).map do |day|
      date = date_by_day(@date, day)
      date.saturday? || date.sunday? ? weekend : work
    end
  end

  def table_header_styles
    styles = [:header]
    styles += calendar_styles(:header_weekend, :header)
    styles << :header
  end

  def table_user_styles
    styles = [:name_cell]
    styles += calendar_styles(:weekend_cell, :default_cell)
    styles << :default_cell
  end

  def total_styles
    styles = [:total]
    all_days_in_month(@date).each { styles << :default_cell }
    styles << :bold_cell
  end

  def report_width
    report_table_header.size
  end

  def column_widths
    col_widths = [NAME_COLUMN_WIDTH]
    9.times { col_widths << ONE_SIGN_DAY_COLUMN_WIDTH }
    (report_width - 11).times { col_widths << TWO_SIGN_DAY_COLUMN_WIDTH }
    col_widths << TOTAL_COLUMN_WIDTH
  end
end
