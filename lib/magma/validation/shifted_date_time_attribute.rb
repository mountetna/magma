# class Magma
#   class Validation
#     class ShiftedDateTimeAttribute < Magma::Validation::Model
#       def validate(record_name, document)
#         document.each do |att_name, value|
#           next unless @model.attributes[att_name].is_a?(Magma::ShiftedDateTimeAttribute)

#           attribute_validations(att_name).validate_shift(record_name, document, value) do |error|
#             yield error
#           end
#         end
#       end

#       private

#       def attribute_validations(att_name)
#         @attribute_validations[att_name] ||= validation(@model.attributes[att_name]).new(
#           @model, @validator, @model.attributes[att_name]
#         )
#       end

#       def validation(att)
#         raise "Shifted date time attributes require a distinct validation implementation" unless att.class.const_defined?(:Validation)

#         att.class.const_get(:Validation)
#       end
#     end
#   end
# end
