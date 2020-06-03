class Magma::Dictionary
  def initialize(options = {})
    @dict_model_name = options.delete(:dictionary_model)
    @attributes = options.transform_values(&:to_sym)
  end

  def entries
    dict_model.all
  end

  # checks the given document to see if it conforms to the given dictionary entry
  def matches_entry?(entry, document)
    @attributes.all? do |model_att_name,dict_att_name|
      matches_entry_attribute?(
        entry[dict_att_name],
        document[model_att_name],
        dict_model.attributes[dict_att_name]
      )
    end
  end

  def to_s
    @dict_model_name
  end

  def to_hash
    {
      project_name: dict_model.project_name,
      model_name: dict_model.model_name,
      attributes: @attributes
    }
  end

  private

  def dict_model
    @dict_model ||= @dict_model_name.constantize
  end

  def matches_entry_attribute?(match_entry, document_value, match_att)
    case match_att
    when Magma::MatchAttribute
      return json_match?(match_entry, document_value)
    else
      return match_entry == document_value
    end
  end

  def json_match?(match_entry, document_value)
    match_value = match_entry['value']

    case match_entry['type']
    when 'Array'
      return match_value.include?(document_value)
    when 'Range'
      return Range.new(*match_value).include?(document_value)
    when 'Regexp'
      return Regexp.new(match_value).match(document_value)
    else
      return match_value == document_value
    end
    return nil
  end
end
