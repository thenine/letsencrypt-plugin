module LetsencryptPlugin
  class CertificateOutput
    def initialize(csr, cert)
      @csr = csr
      @certificate = cert
    end

    def output
      display_info

      output_cert('key.pem', @csr.private_key.to_pem)
      output_cert('fullchain.pem', @certificate)
    end
  end
end
