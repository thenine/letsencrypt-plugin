require 'letsencrypt_plugin/certificate_output'

module LetsencryptPlugin
  class FileOutput < CertificateOutput
    def initialize(csr, cert, out_dir)
      super(csr, cert)
      @output_dir = out_dir
    end

    def output_cert(name, cert_content)
      File.write(File.join(@output_dir, name), cert_content)
      Rails.logger.info("- #{name} created")
    end

    def display_info
      Rails.logger.info('Saving certificates and key')
    end
  end
end
