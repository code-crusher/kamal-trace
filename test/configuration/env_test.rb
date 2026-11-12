require "test_helper"

class ConfigurationEnvTest < ActiveSupport::TestCase
  require "test_helper"

  test "simple" do
    assert_config \
      config: { "foo" => "bar", "baz" => "haz" },
      clear: { "foo" => "bar", "baz" => "haz" }
  end

  test "clear" do
    assert_config \
      config: { "clear" => { "foo" => "bar", "baz" => "haz" } },
      clear: { "foo" => "bar", "baz" => "haz" }
  end

  test "secret" do
    with_test_secrets("secrets" => "PASSWORD=hello") do
      assert_config \
        config: { "secret" => [ "PASSWORD" ] },
        secrets: { "PASSWORD" => "hello" }
    end
  end

  test "missing secret" do
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration::Env.new(
        config: { "secret" => [ "PASSWORD" ] },
        secrets: Kamal::Secrets.new(secrets_path: ".kamal/secrets")
      ).secrets_io
    end
  end

  test "secret and clear" do
    with_test_secrets("secrets" => "PASSWORD=hello") do
      config = {
        "secret" => [ "PASSWORD" ],
        "clear" => {
          "foo" => "bar",
          "baz" => "haz"
        }
      }

      assert_config \
        config: config,
        clear: { "foo" => "bar", "baz" => "haz" },
        secrets: { "PASSWORD" => "hello" }
    end
  end

  test "aliased secrets" do
    with_test_secrets("secrets" => "ALIASED_PASSWORD=hello") do
      config = {
        "secret" => [ "PASSWORD:ALIASED_PASSWORD" ],
        "clear" => {}
      }

      assert_config \
        config: config,
        clear: {},
        secrets: { "PASSWORD" => "hello" }
    end
  end

  test "required secret" do
    with_test_secrets("secrets" => "PASSWORD=hello") do
      assert_config \
        config: { "secret" => [ "PASSWORD!" ] },
        secrets: { "PASSWORD" => "hello" }
    end
  end

  test "required aliased secret" do
    with_test_secrets("secrets" => "ALIASED_PASSWORD=hello") do
      assert_config \
        config: { "secret" => [ "PASSWORD:ALIASED_PASSWORD!" ] },
        secrets: { "PASSWORD" => "hello" }
    end
  end

  test "required empty secret" do
    with_test_secrets("secrets" => "PASSWORD=") do
      env = Kamal::Configuration::Env.new config: { "secret" => [ "PASSWORD!" ] }, secrets: Kamal::Secrets.new(secrets_path: ".kamal/secrets")

      error = assert_raises(Kamal::ConfigurationError) { env.ensure_required_secrets_present! }
      assert_equal "env: Secret 'PASSWORD' is required but is empty", error.message
    end
  end

  test "required missing secret" do
    with_test_secrets("secrets" => "OTHER=hello") do
      env = Kamal::Configuration::Env.new config: { "secret" => [ "PASSWORD!" ] }, secrets: Kamal::Secrets.new(secrets_path: ".kamal/secrets")

      error = assert_raises(Kamal::ConfigurationError) { env.ensure_required_secrets_present! }
      assert_equal "env: Secret 'PASSWORD' not found in .kamal/secrets", error.message
    end
  end

  test "empty secret without marker is allowed" do
    with_test_secrets("secrets" => "PASSWORD=") do
      assert_config \
        config: { "secret" => [ "PASSWORD" ] },
        secrets: { "PASSWORD" => "" }
    end
  end

  private
    def assert_config(config:, clear: {}, secrets: {})
      env = Kamal::Configuration::Env.new config: config, secrets: Kamal::Secrets.new(secrets_path: ".kamal/secrets")
      expected_clear_args = clear.to_a.flat_map { |key, value| [ "--env", "#{key}=\"#{value}\"" ] }
      assert_equal expected_clear_args, env.clear_args.map(&:to_s) #  to_s removes the redactions
      expected_secrets = secrets.to_a.flat_map { |key, value| "#{key}=#{value}" }.join("\n") + "\n"
      assert_equal expected_secrets, env.secrets_io.string
    end
end
