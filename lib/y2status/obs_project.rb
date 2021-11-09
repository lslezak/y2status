
require "English"
require "csv"
require "shellwords"
require "timeout"

module Y2status
  # Open Build Service project
  class ObsProject
    include Downloader
    include Reporter

    attr_reader :api, :name, :error_status, :error_requests, :packages, :ignore

    def initialize(name, packages: nil, api: nil, ignore: nil)
      @name = name
      @api = api
      @packages = packages
      @ignore = ignore || []
      @ignore.map! { |i| Regexp.new(i) }
    end

    def builds
      @builds ||= download_builds
    end

    def declined_requests
      @requests ||= download_declined_requests
    end

    def project_url
      "#{web_url}/project/show/#{name}"
    end

    def web_url
      if api.nil?
        "https://build.opensuse.org"
      elsif api == "https://api.suse.de"
        "https://build.suse.de"
      else
        # fallback for an unknown OBS instance
        api
      end
    end

    def builds?
      !builds.any?(&:failure?)
    end

    def declined?
      !declined_requests.empty?
    end

    def error?
      error_status? || error_requests?
    end

    def error_status?
      error_status && !error_status.empty?
    end

    def error_requests?
      error_requests && !error_requests.empty?
    end

    def success?
      builds? && !declined?
    end

    def issues
      builds.count(&:failure?) + declined_requests.size
    end

  private

    attr_writer :status

    # Get the OBS project build state
    #
    # @param [String] project the project name
    # @param [String,nil] api the API URL
    #
    # @return [Array<ObsBuild>] the found OBS builds
    #
    def download_builds
      opt = api ? "-A #{Shellwords.escape(api)} " : ""
      cmd = "osc #{opt}prjresults --csv #{Shellwords.escape(name)}"

      table = CSV.parse(execute(cmd), col_sep: ";", headers: true)

      table.each_with_object([]) do |row, list|
        row.each do |name, status|
          # skip the name pair from the header
          next if name == "_"

          package = row["_"]
          target = name.sub(/\/[^\/]*$/, "")

          next if packages && !packages.include?(package)
          next if ignore && ignore.any? { |i| target =~ i }

          list << ObsBuild.new(self, package, target, status)
        end
      end
    end

    def execute(cmd)
      print_progress("Running \"#{cmd}\"...")

      begin
        out = Timeout.timeout(15) { `#{cmd}` }
      rescue Timeout::Error
        @error_requests = "Command #{cmd} timed out"
        print_error(error_requests)
        return ""
      end

      return out if $CHILD_STATUS.success?

      @error_requests = "Command #{cmd} failed"
      print_error(error_requests)
      return ""
    end

    def download_declined_requests
      opt = api ? "-A #{Shellwords.escape(api)} " : ""
      cmd = "osc #{opt}request list -s declined #{Shellwords.escape(name)}"

      # the requests are separated by empty lines
      execute(cmd).split("\n\n").each_with_object([]) do |r, list|
        next unless r =~ /\A(\d+).*\n\s*(?:maintenance_incident|submit): (.*?)\n/m
        sr_id = Regexp.last_match[1]
        submit = Regexp.last_match[2].strip.squeeze(" ")

        if packages
          next unless submit =~ /^#{Regexp.escape(name)}\/([^@]+)/
          package = Regexp.last_match[1]
          next unless packages.include?(package)
        end

        # remove repeated spaces by #squeeze
        list << ObsRequest.new(self, sr_id, submit)
      end
    end
  end
end
