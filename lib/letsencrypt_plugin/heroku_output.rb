require 'letsencrypt_plugin/certificate_output'

module LetsencryptPlugin
  class HerokuOutput < CertificateOutput
    def initialize(csr, cert)
      super(csr, cert)
    end

    def output_cert(name, cert_content)
      Rails.logger.info("====== #{name} ======")
      puts cert_content
    end

    def display_info
      Rails.logger.info('You are running this script on Heroku, please copy-paste certificates to your local machine')
      Rails.logger.info('and then follow https://devcenter.heroku.com/articles/ssl-endpoint guide:')
    end
  end
end
