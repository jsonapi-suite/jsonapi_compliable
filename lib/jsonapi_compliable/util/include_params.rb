# TODO - better code for:
# * Validating requested params
# * Transforming options[:include] to render_jsonapi
module JsonapiCompliable
  module Util
    class IncludeParams
      def self.compare(includes, sideloads, action_name, alternate = false)
        {}.tap do |valid|
          includes.to_hash.each_pair do |key, sub_hash|
            sideload = sideloads._includes[key]

            if sideload && sideload.allowed?(action_name)
              if alternate
                valid[sideloads._includes[key].as] = compare(sub_hash, sideloads._includes[key], action_name, alternate)
              else
                valid[key] = compare(sub_hash, sideloads._includes[key], action_name)
              end
            end
          end
        end
      end

      def self.scrub(controller, alternate = false)
        dsl       = controller._jsonapi_compliable
        includes  = JSONAPI::IncludeDirective.new(controller.params[:include])

        if dsl.sideloads
          Util::IncludeParams.compare \
            includes,
            dsl.sideloads,
            controller.action_name.to_sym,
            alternate
        else
          {}
        end
      end
    end
  end
end
