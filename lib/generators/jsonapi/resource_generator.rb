module Jsonapi
  class ResourceGenerator < ::Rails::Generators::NamedBase
    source_root File.expand_path('../templates', __FILE__)

    argument :attributes, type: :array, default: [], banner: "field[:type][:index] field[:type][:index]"

    class_option :omit_comments,
                 type: :boolean,
                 default: true,
                 aliases: %w[-c],
                 desc: 'Generate without documentation comments'
    class_option :actions,
                 type: :array,
                 default: nil,
                 aliases: %w[-a],
                 desc: 'Array of controller actions to support, e.g. "index show destroy"'

    desc "This generator creates a resource file at app/resources, as well as corresponding controller/specs/route/etc"
    def copy_resource_file
      unless model_klass
        raise "You must define a #{class_name} model before generating the corresponding resource."
      end

      generate_controller
      generate_serializer
      generate_application_resource unless application_resource_defined?
      generate_spec_payload

      if actions?('create', 'update')
        generate_strong_resource
      end

      generate_route
      generate_tests
      generate_resource
      generate_swagger if docs_controller?
    end

    private

    def actions
      @options['actions'] || %w(index show create update destroy)
    end

    def actions?(*methods)
      methods.any? { |m| actions.include?(m) }
    end

    def omit_comments?
      @options['omit-comments']
    end

    def generate_controller
      to = File.join('app/controllers', class_path, "#{file_name.pluralize}_controller.rb")
      template('controller.rb.erb', to)
    end

    def generate_serializer
      to = File.join('app/serializers', class_path, "#{serializable_file_name}.rb")
      template('serializer.rb.erb', to)
    end

    def generate_application_resource
      to = File.join('app/resources', class_path, "application_resource.rb")
      template('application_resource.rb.erb', to)
    end

    def application_resource_defined?
      'ApplicationResource'.safe_constantize.present?
    end

    def docs_controller?
      File.exists?('app/controllers/docs_controller.rb')
    end

    def generate_swagger
      code = "  jsonapi_resource '/v1/#{url}'"
      code << ", only: [#{actions.map { |a| ":#{a}" }.join(', ')}]" if actions.length < 5
      code << "\n"
      inject_into_file 'app/controllers/docs_controller.rb', before: /^end/ do
        code
      end
    end

    def generate_spec_payload
      to = File.join('spec/payloads', class_path, "#{file_name}.rb")
      template('payload.rb.erb', to)
    end

    def generate_strong_resource
      code = "  strong_resource :#{singular_table_name} do\n"
      attributes.each do |a|
        type = a.type
        type = :string if type == :text
        type = :number if [:float, :decimal].include?(type)
        code << "    attribute :#{a.name}, :#{type}\n"
      end
      code << "  end\n"

      inject_into_file 'config/initializers/strong_resources.rb', after: "StrongResources.configure do\n" do
        code
      end
    end

    def generate_route
      code = "      resources :#{type}"
      code << ", only: [#{actions.map { |a| ":#{a}" }.join(', ')}]" if actions.length < 5
      code << "\n"

      unless type == url
        code = code.gsub("resources :#{type}", "resources :#{file_name.pluralize}")
        url.split('/')[0..-2].reverse.each do |namespace|
          code = "      namespace :#{namespace} do\n#{indent(code).chomp}\n      end\n"
        end
      end

      inject_into_file 'config/routes.rb', after: /scope path: (['"])\/v1(['"]) do\n/ do
        code
      end
    end

    def generate_tests
      if actions?('index')
        to = File.join "spec/api/v1", url, "index_spec.rb"
        template('index_request_spec.rb.erb', to)
      end

      if actions?('show')
        to = File.join "spec/api/v1", url, "show_spec.rb"
        template('show_request_spec.rb.erb', to)
      end

      if actions?('create')
        to = File.join "spec/api/v1", url, "create_spec.rb"
        template('create_request_spec.rb.erb', to)
      end

      if actions?('update')
        to = File.join "spec/api/v1", url, "update_spec.rb"
        template('update_request_spec.rb.erb', to)
      end

      if actions?('destroy')
        to = File.join "spec/api/v1", url, "destroy_spec.rb"
        template('destroy_request_spec.rb.erb', to)
      end
    end

    def generate_resource
      to = File.join('app/resources', class_path, "#{file_name}_resource.rb")
      template('resource.rb.erb', to)
    end

    def jsonapi_config
      File.exists?('.jsonapicfg.yml') ? YAML.load_file('.jsonapicfg.yml') : {}
    end

    def update_config!(attrs)
      config = jsonapi_config.merge(attrs)
      File.open('.jsonapicfg.yml', 'w') { |f| f.write(config.to_yaml) }
    end

    def prompt(header: nil, description: nil, default: nil)
      say(set_color("\n#{header}", :magenta, :bold)) if header
      say("\n#{description}") if description
      answer = ask(set_color("\n(default: #{default}):", :magenta, :bold))
      answer = default if answer.blank? && default != 'nil'
      say(set_color("\nGot it!\n", :white, :bold))
      answer
    end

    def api_namespace
      @api_namespace ||= begin
        ns = jsonapi_config['namespace']

        if ns.blank?
          ns = prompt \
            header: "What is your API namespace?",
            description: "This will be used as a route prefix, e.g. if you want the route '/books_api/v1/authors' your namespace would be 'books_api'",
            default: 'api'
          update_config!('namespace' => ns)
        end

        ns
      end
    end

    def serializable_file_name
      "serializable_#{file_name}"
    end

    def serializable_class_name
      (class_path + [serializable_file_name]).map!(&:camelize).join("::")
    end

    def model_klass
      class_name.safe_constantize
    end

    def type
      model_klass.model_name.plural
    end

    def url
      model_klass.model_name.collection
    end
  end
end
