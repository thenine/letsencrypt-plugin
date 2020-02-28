require 'letsencrypt_plugin/engine'
require 'letsencrypt_plugin/file_output'
require 'letsencrypt_plugin/heroku_output'
require 'letsencrypt_plugin/file_store'
require 'letsencrypt_plugin/database_store'
require 'letsencrypt_plugin/configuration'
require 'letsencrypt_plugin/private_key_store'
require 'acme-client'

module LetsencryptPlugin
  def self.config
    # load files on demand
    @config ||= Configuration.load_file
  end

  def self.config=(config)
    @config = config
  end

  class CertGenerator
    attr_reader :options, :cert, :client

    def initialize(options = {})
      @options = options
      @options.freeze
    end

    def generate_certificate
      register
      domains = @options[:domain].split(' ')
      Rails.logger.info('Creating order')
      @order = client.new_order(identifiers: domains)
      Rails.logger.info('- Order created')
      return unless authorize_and_handle_challenge(domains)
      # We can now request a certificate
      Rails.logger.info('Creating CSR')
      @csr = Acme::Client::CertificateRequest.new(names: domains)
      Rails.logger.info('- CSR created')
      Rails.logger.info('Finalizing order')
      @cert = finalize_order(@csr)
      Rails.logger.info('- Order finalized')
      save_certificate(@csr, @cert)
      Rails.logger.info('Certificate has been generated')
    end

    def authorize_and_handle_challenge(domains)
      result = false
      @order.authorizations.each do |authorization|
        Rails.logger.info("Sending authorization request for: #{authorization.domain}")
        @authorization = authorization
        handle_challenge
        request_challenge_verification
        result = valid_verification_status
        Rails.logger.info('- Verification valid') if result
        break unless result
      end
      result
    end

    def client
      @client ||= Acme::Client.new(private_key: private_key, directory: @options[:directory])
    end

    def private_key
      store ||= PrivateKeyStore.new(private_key_from_db) if @options.fetch(:private_key_in_db, false)

      pk_id = @options.fetch(:private_key, nil)

      raise 'Private key is not set, please check your config/letsencrypt_plugin.yml file!' if pk_id.nil? || pk_id.empty?

      store ||= PrivateKeyStore.new(private_key_from_file(private_key_path(pk_id))) if File.file?(private_key_path(pk_id))

      raise "Can not open private key: #{private_key_path(pk_id)}" if File.directory?(private_key_path(pk_id))

      store ||= PrivateKeyStore.new(pk_id)
      store.retrieve
    end

    def private_key_path(private_key_file)
      Rails.root.join(private_key_file)
    end

    def private_key_from_db
      settings = LetsencryptPlugin::Setting.first
      raise 'Empty private_key field in settings table!' if settings.private_key.nil?
      settings.private_key
    end

    def private_key_from_file(filepath)
      File.read(filepath)
    end

    def register
      Rails.logger.info('Trying to register at Let\'s Encrypt service')
      registration = client.new_account(contact: "mailto:#{@options[:email]}", terms_of_service_agreed: true)
      Rails.logger.info("- Registered as #{@options[:email]}")
    rescue => e
      Rails.logger.info("#{e.class} - #{e.message}. Already registered.")
    end

    def common_domain_name
      @domain ||= @options[:cert_name] || @options[:domain].split(' ').first.to_s
    end

    def store_challenge(challenge)
      if @options[:challenge_dir_name].nil? || @options[:challenge_dir_name].empty?
        DatabaseStore.new(challenge.file_content).store
      else
        FileStore.new(challenge.file_content, @options[:challenge_dir_name]).store
      end
      sleep(2)
    end

    def handle_challenge
      @challenge = @authorization.http
      store_challenge(@challenge)
    end

    def request_challenge_verification
      Rails.logger.info('- Requesting challenge verification')
      @challenge.request_validation
    end

    def wait_for_status(challenge)
      Rails.logger.info('- Waiting for challenge status')
      counter = 0
      while challenge.status == 'pending' && counter < 10
        Rails.logger.info("-- Counter: #{counter}")
        sleep(1)
        challenge.reload
        counter += 1
      end
    end

    def valid_verification_status
      wait_for_status(@challenge)
      return true if @challenge.status == 'valid'
      Rails.logger.error('- Challenge verification failed')
      Rails.logger.error("Error: #{@challenge.error['type']}: #{@challenge.error['detail']}")
      false
    end

    def finalize_order(csr)
      @order.finalize(csr: csr)
      while @order.status == 'processing'
        sleep(1)
        challenge.reload
      end
      @order.certificate
    end

    # Save the certificate and key
    def save_certificate(csr, certificate)
      return unless certificate
      return HerokuOutput.new(common_domain_name, certificate).output unless ENV['DYNO'].nil?
      output_dir = File.join(Rails.root, @options[:output_cert_dir])
      return FileOutput.new(csr, certificate, output_dir).output if File.directory?(output_dir)
      Rails.logger.error("Output directory: '#{output_dir}' does not exist!")
    end
  end
end
