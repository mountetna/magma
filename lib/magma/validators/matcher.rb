# A dictionary is a special model/table that houses definitions of fields and
# their possible values. When the Matcher is initialized it is set with a
# dictionary. When the 'match' function is run it will look in the dictionary
# for a field name and pull the possible matches for that field. It will then
# compare that field value to the incoming data value. Since looking up the
# fields are db calls we memoize the possible field values for subsequent
# matches of the same field.

class Magma
  class Matcher
    def initialize(dictionary)
      @dictionary = dictionary
      @fields = {}
    end

    def match(data_name, data_value)

      # Select or build the entry to match against.
      match_value = @fields[data_name] ||= build_matcher(data_name)

      # If there is no entry in the DB to match against then, obviously, we
      # can't match/verify the data.
      return false if match_value == nil

      # Match the incoming data_value against it's type and 
      matched = run_match(match_value, data_value)
      return matched
    end

    private

    def run_match(match_value, data_value)
      errors = []
      case match_value[:type]

      when 'string'

        # Most data in the DB will be stored as a string regardless.
        begin
          String(data_value)
          return true
        rescue ArgumentError
          return false
        end
      when 'number'

        # Check for an integer.
        begin
          Integer(data_value)
          return true
        rescue ArgumentError
          errors.push('data_value is not an integer.')
        end

        # Check for a float.
        begin
          Float(data_value)
          return true
        rescue ArgumentError
          errors.push('data_value is not a float.')
        end

        # If data_value is not an integer or a float then return false.
        return false
      when 'boolean'

        # Check for a boolean format.
        bools = ['T','t','True','true',true,'1',1]
        bools.concat(['F','f','False','false',false,'0',0])
        return bools.include?(data_value)
      when 'date'

        # Check for a date format.
        begin
          DateTime.parse(data_value)
          return true
        rescue ArgumentError
          errors.push('data_value is not a date.')
          return false
        end
        
      when 'regex'

        # First check that the match value is a regular expression.
        begin
          regex = Regexp.new(match_value[:value])
        rescue ArgumentError
          errors.push('value is not a regular expression.')
          return false
        end

        # Then evaluate the regular expression. The regular expression should
        # match exactly once.
        matches = regex.match(data_value)
        return (matches != nil && matches.length == 1) ? true : false
      else

        # The type is unknown...obviously there is no match.
        return false
      end
    end

    # Extract fields from the set dictionary and build entries to match against.
    def build_matcher(data_name)

      # Extract the possible field values by the field name.
      dict_rows = @dictionary.where(Sequel.like(:name, data_name)).all

      if dict_rows.length == 0
        return nil
      elsif dict_rows.length == 1
        return build_single_matcher(dict_rows[0])
      elsif dict_rows.length > 1
        return build_regex_matcher(dict_rows)
      else
        return nil
      end
    end

    def build_single_matcher(dict_row)
      if /^string|number|date|boolean|regex$/.match(dict_row[:type])
        return {type: dict_row[:type]}
      else
        return nil
      end
    end

    def build_regex_matcher(dict_rows)

      errors = []
      matches = []

      # Place all the regex matches into an array. Also check to make sure all
      # of the entries have the correct type.
      dict_rows.each do |row|
        if row[:type] == 'regex'
          matches.push(row[:value])
        else
          err = "Dictionary #{@dictionary.class.to_s} has an invalid "\
"'name': #{row[:name]}, 'value': #{row[:value]}, "\
"'type': #{row[:type]}. Should be 'type': 'regex'."
          errors.push(err)
        end
      end

      # If there was an error in the dictionary then don't continue.
      return nil if errors.length > 0

      return {
        type: 'regex',
        value: "^#{dict_rows.map(&:value).join('$|^')}$"
      }
    end
  end
end