class Kamal::Configuration::Env
  include Kamal::Configuration::Validation

  attr_reader :context, :clear, :secrets, :secret_keys
  delegate :argumentize, to: Kamal::Utils

  def initialize(config:, secrets:, context: "env")
    @clear = config.fetch("clear", config.key?("secret") || config.key?("tags") ? {} : config)
    @secrets = secrets
    @secret_keys = config.fetch("secret", [])
    @context = context
    validate! config, context: context, with: Kamal::Configuration::Validator::Env
  end

  def clear_args
    argumentize("--env", clear)
  end

  def secrets_io
    Kamal::EnvFile.new(aliased_secrets).to_io
  end

  def merge(other)
    self.class.new \
      config: { "clear" => clear.merge(other.clear), "secret" => secret_keys | other.secret_keys },
      secrets: secrets
  end

  def to_h
    clear.merge(aliased_secrets)
  end

  def ensure_required_secrets_present!
    required_secret_keys.each do |key|
      secrets[key, required: true]
    rescue Kamal::ConfigurationError => e
      raise Kamal::ConfigurationError, "#{context}: #{e.message}"
    end
  end

  private
    def aliased_secrets
      secret_keys.each_with_object({}) do |key, aliased_secrets|
        key_name, secret_key, required = extract_alias(key)
        aliased_secrets[key_name] = secrets[secret_key, required: required]
      end
    end

    def required_secret_keys
      secret_keys.filter_map do |key|
        _key_name, secret_key, required = extract_alias(key)
        secret_key if required
      end
    end

    def extract_alias(key)
      key, required = key.end_with?("!") ? [ key.delete_suffix("!"), true ] : [ key, false ]
      key_name, key_aliased_to = key.split(":", 2)
      [ key_name, key_aliased_to || key_name, required ]
    end
end
