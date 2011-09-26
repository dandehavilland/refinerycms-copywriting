require 'active_support'

class CopywritingPhrase < ActiveRecord::Base

  belongs_to :page
  translates :value if self.respond_to?(:translates)
  validates :name, :presence => true

  attr_accessible :locale, :name, :default, :value, :scope, :page_id, :phrase_type

  def self.for(name, options = {})
    options = {:phrase_type => 'text', :scope => 'default'}.merge(options)
    name = name.to_s
    options[:page_id] = (options[:page].try(:id) || options[:page_id] || nil)

    if (phrase = self.where(:name => name, :page_id => options[:page_id]).first).nil?
      phrase = self.create(:name => name,
                           :scope => options[:scope],
                           :value => options[:value],
                           :default => options[:default],
                           :page_id => options[:page_id],
                           :phrase_type => options[:phrase_type])
    end
    
    phrase.send :interpolate, name, options
  end

  def default_or_value
    value.blank? ? default : value 
  end
  
  protected
  def interpolate(name, options = {})
    
    phrase = default_or_value.dup
    targets = (phrase||"").scan(/(\%[^\%]+\%)/).flatten
    
    # raise Exception("Self-referencing CopywritingPhrase #{name} cannot be processed") if (targets.include?("%#{name}%"))
    return phrase if (targets.include?("%#{name}%"))
    
    unless (targets.empty?)
      
      # make sure we're not creating a new copywriting phrase with the same values
      options.delete(:default)
      options.delete(:value)
      
      # and ensure we can access the replacements
      options[:replacements] = (options[:replacements]||{}).stringify_keys
      
      targets.each do |target|
        
        key = target.gsub("%","")
        
        # does it relate to a passed replacement?
        if (other = options[:replacements][key].to_s)
          phrase.gsub!(target, other)
        
        # does it relate to a copywriting
        elsif (other = CopywritingPhrase.for(key, options))
          phrase.gsub!(target, other.blank? ? "<value missing or not supplied for #{key}>" : other)
        end
      end
    end
    phrase
  end
end