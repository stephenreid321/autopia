class Delayed::Job
  class RunError < StandardError; end

  after_destroy do
    if last_error
      begin
        raise Delayed::Job::RunError
      rescue StandardError => e
        Airbrake.notify(e, delayed_job: JSON.parse(to_json))
      end
    end
  end
end
