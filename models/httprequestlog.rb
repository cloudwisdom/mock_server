# encoding: utf-8
require 'uri'

class Httprequestlog < ActiveRecord::Base

  validates :request_http_verb, presence: true
  validates :request_url, presence: true
  validates :request_headers, presence: true
  validates :request_environment, presence: true

  #
  # Save the incoming http request, save only the headers and the body along with the request method and query string and url
  # @param [Hash] request sinatra request hash
  # @return nil
  #
  def save_http_request(request)
    self.request_http_verb = request.env['REQUEST_METHOD']
    self.request_url = request.env['PATH_INFO']
    self.request_query_string = request.env['QUERY_STRING']

    output = ''
    request.env.each do |k, v|
      output << "#{k} => #{v} \n" unless k.match(/[rack,sinatra]/)
    end
    self.request_headers = output

    body_text = request.body.read
    if body_text && body_text.length > 0
      begin
        self.request_body = URI.decode(body_text)
      rescue
        # Hack for now to log body any way
        self.request_body = body_text
      end
    else
      self.request_body = ''
    end
    self.request_environment = ENV['TEST_ENV']
    self.request_http_verb = self.request_http_verb.upcase
    self.created_at = Time.new.strftime('%Y-%m-%d %H:%M:%S')
  end

  #
  # Deletes all rows from the httprequestlogs table
  #
  def self.clear_request_log
    Httprequestlog.delete_all
  end

  #
  # Get the request logs from a start date time to the end date time. If no end datetime is specified the current
  # date time is assumed. If no start time is provided then time 10 minutes ago is taken.
  # @param [String,[String]] start_datetime and end_datetime in format ('%Y-%m-%d %H:%M:%S', ...)
  # @return [JSON] request log data in JSON format or empty JSON if no data
  #
  def self.get_request_log(start_datetime=(Time.now - (ENV['RECENT_LOG_DURATION'].to_i)).strftime('%Y-%m-%d %H:%M:%S'),
      end_datetime=Time.new.strftime('%Y-%m-%d %H:%M:%S'),
      matching=nil
  )
    if matching.nil?
      data = where("created_at >= :start_datetime AND created_at <= :end_datetime",
                   {start_datetime: start_datetime, end_datetime: end_datetime}).order('created_at DESC')
    else
      match_string = '%' + matching + '%'
      data = where("(created_at >= :start_datetime AND created_at <= :end_datetime) AND request_url like :match_string",
                   {start_datetime: start_datetime, end_datetime: end_datetime, match_string: match_string}).order('created_at DESC')
    end

    if data.any?
      return data.to_json
    else
      return '[{"message" : "No request logs found"}]'
    end
  end

  #
  # Get the details of the logged HTTP request
  # @param [Fixnum] log_row_id Id of the database row for the logged http request
  # @return [Hash] The logged request row in JSON format
  #
  def self.get_log_details(log_row_id)
    data = where(id: log_row_id)
    if data.any?
      return data.first
    else
      return '{"message" : "Log does not exist."}'
    end
  end
end