class RenderReportExcelJob < FhlbJob
  include CustomFormattingHelper
  queue_as :high_priority

  def perform(member_id, report_name, filename, params={}, report_view=nil)
    controller = ReportsController.new
    controller.request = ActionDispatch::TestRequest.new
    controller.response = ActionDispatch::TestResponse.new
    return if job_status.canceled?
    member = MembersService.new(controller.request).member(member_id)
    raise 'Member not found!' unless member

    controller.request.env['warden'] = FhlbMember::WardenProxy.new(job_status.user)
    controller.skip_deferred_load = true
    controller.session[ReportsController::SessionKeys::MEMBER_ID] = member_id
    controller.session[ReportsController::SessionKeys::MEMBER_NAME] = member[:name]
    controller.params = params
    controller.action_name = report_name
    return if job_status.canceled?
    controller.public_send(report_name.to_sym)
    return if job_status.canceled?
    xlsx = controller.render_to_string(template: "reports/#{report_name}", handlers: [:axlsx], formats: [:xlsx])
    file = StringIOWithFilename.new(xlsx)
    file.content_type = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    filename ||= controller.report_download_name
    filename ||= "#{controller.action_name.to_s.gsub('_','-')}-#{fhlb_report_date_numeric(Time.zone.today)}" if controller.action_name
    file.original_filename = "#{filename}.xlsx"
    return if job_status.canceled?
    job_status.result = file
    job_status.save!
    file.rewind
    file
  end
end
