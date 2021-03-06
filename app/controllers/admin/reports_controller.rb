class Admin::ReportsController < ApplicationController
  ActionController::Renderers.add :csv do |detailed_report, options|
    headers['Cache-Control']             = 'must-revalidate, post-check=0, pre-check=0'
    headers['Content-Disposition']       = "attachment; filename=#{detailed_report.filename}.csv"
    headers['Content-Type']              = 'text/csv'
    headers['Content-Transfer-Encoding'] = 'binary'

    self.response_body = detailed_report.to_csv
  end

  before_filter :authenticate_user!

  def index
  end

  def progress
    report = EditorialProgressPresenter.new(Edition.not_in(state: ["archived"]))
    render csv: report
  end

  def business_support_schemes_content
    schemes = BusinessSupportEdition.published.asc("title")
    send_data BusinessSupportExportPresenter.new(schemes).to_csv, :filename => 'business_support_schemes_content.csv'
  end
end
