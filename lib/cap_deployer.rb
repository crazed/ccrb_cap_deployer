# This plugin will deploy your app using capistrano.
# If the build fails the app won't de be deployed and if it passes it will try to deploy to a list of stages you can supply.
# It will send an email notifying if it was successful or not and a special artifact with the capistrano output will be created.
#
# Configuration
# In your project's cruise_config.rb file:
#
# Set the email addresses which should be notified about deployment
# project.cap_deployer.emails = ['email@example.com']
#
#
# Important: this plugin assumes you are using ssh keys for deployment
#
class CapDeployer
  attr_accessor :emails
  attr_writer :from
 
  def initialize(project = nil)
    @emails = []
    @stages = []
  end
 
  def from
    @from || Configuration.email_from
  end
 
  def logger
    CruiseControl::Log
  end
 
  def build_finished(build)
    return if build.failed?
    deploy build
  end
 
  private
 
  def deploy(build)
    logger.info DateTime.now.strftime("%Y-%m-%d %H:%M:%S") + " cap_deployer: Starting deployment"
    path = build.project.path + "/work/"
    success = system "cd #{path} && cap deploy > #{build.artifacts_directory}/cap_deploy.txt"
    logger.info DateTime.now.strftime("%Y-%m-%d %H:%M:%S") + " cap_deployer: Deployment #{success ? 'successful' : 'failed'}"
    notify(success, build, stage.to_s)
    logger.info DateTime.now.strftime("%Y-%m-%d %H:%M:%S") + " cap_deployer: Finished deployment"
  end
 
  def notify(success, build, stage)
    if success
      email :deliver_build_report, build, "#{build.project.name} build #{build.label} has been deployed", "The build was deployed."
    else
      email :deliver_build_report, build, "#{build.project.name} build #{build.label} could not be deployed", "The build could not be deployed."
    end
  end
 
  def email(template, build, *args)
    BuildMailer.send(template, build, @emails, from, *args)
    CruiseControl::Log.event("Sent e-mail to #{@emails.size == 1 ? "1 person" : "#{@emails.size} people"}", :debug)
  rescue => e
    settings = ActionMailer::Base.smtp_settings.map { |k,v| " #{k.inspect} = #{v.inspect}" }.join("\n")
    CruiseControl::Log.event("Error sending e-mail - current server settings are :\n#{settings}", :error)
    raise
  end
 
 
end
 
Project.plugin :cap_deployer
