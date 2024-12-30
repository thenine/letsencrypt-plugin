module LetsencryptPlugin
  class CertificateOutput
    def initialize(domain, cert)
      @domain = domain
      @certificate = cert
    end

    def output
      display_info

     # output_cert('key.pem', @csr.private_key.to_pem)
      output_cert('key.pem', @certificate) # request.private_key.to_pem)
      output_cert('fullchain.pem', @certificate) # fullchain_to_pem)
    end
  end
end
