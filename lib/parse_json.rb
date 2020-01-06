# This script is for screwing around with parsing the MDN Browser Compat Data JSON file.
# It's very bad right now.
# I'm so sorry.

require 'json'

@data = File.read('public/data.json')

@data = JSON.parse(@data)

# Full version:
# @top_level_schema = {
#   css: ["at-rules", "properties", "selectors", "types"],
#   html: ["elements", "global_attributes"],
#   javascript: ["builtins", "classes", "functions", "grammar", "operators", "statements"]
# }
@top_level_schema = {
  css: ["at-rules", "properties"]
}

@browser_names = {
  chrome: "Chrome",
  edge: "Edge",
  edge_mobile: "Edge Mobile",
  firefox: "Firefox",
  firefox_android: "Firefox Android",
  ie: "Internet Explorer",
  nodejs: "NodeJS",
  opera: "Opera",
  qq_android: "QQ Android",
  safari: "Safari",
  safari_ios: "Safari Mobile",
  samsunginternet_android: "Samsung Internet for Android",
  uc_android: "UC Browser for Android",
  uc_chinese_android: "Chinese UC Browser for Android"
}

# Gets info about each browser
def get_browser_keys(browsers)
  @browser_keys = []

  # Iterates through every browser and adds the key to an array of browsers.
  browsers.each do |key, browser|
    @browser_keys.push(key)
  end
end

def seed_browser_data()
  @browser_keys.each do |key, value|
    # puts key.to_s
    releases = []
    @data['browsers'][key.to_s]['releases'].each_pair do |version, info|
      version_hash = { version: version.to_s }
      info = info.merge(version_hash)
      releases.push(info)
    end
    # puts releases
    # Browser.create(
    #   browser_id: key.to_s,
    #   name: @browser_names.fetch(key.to_sym).to_s,
    #   releases: releases
    # )
  end
end

# This method is intended to provide a means of parsing the browser
# compatibility data schema so data from the schema can be used to
# fill a database. The database will subsequently be used to generate
# graphs with the data. Unfortunately due to the lack of easy diffing,
# the database will need to be regenerated whenever the compatibility
# data JSON is updated.
# 
# This method does the following:
# - Takes the JSON data
# - Parses the schema data on what's described in the top_level_schema
# - Recursively goes through each child until it finds an item named "__compat"
# - The object it has will then have browser info, feature info, etc.
#
# Limitations:
# - It doesn't currently support nested items, e.g. it support css.types.angle
#   but not css.types.angle.deg, it just goes by whatever __compat item it
#   finds first. It's also worth noting that nested items aren't necessarily
#   unique, e.g. html.elements.applet.width and html.elements.canvas.width
#   both exist.
# - It may be useful to generate a list of all the paths for compat data
#   objects, e.g. ["css.properties.background", "css.properties.background-size", ...]
# - It doesn't currently support top-level schema with only one layer. It
#   works with css.at-rules, css.properties, etc. but not with api because the
#   data objects are direct ancestors of the api object, e.g. api.AbortController
#   or api.AbortSignal.
# - It should probably be updated to either use the manual top-level schema
#   (this is useful for testing so the script doesn't need to run through the
#   full set of data) or just run through the entire file until it finds every
#   compat object, depending on the value of a "debug" boolean.
def recursive_parse_browser_data_schema(data_object, iteration, feature_path=[])
  # puts "FUNCTION ARGUMENTS"
  # puts "data_object: #{data_object.to_s.slice(0,300)}"
  # puts "data object key: #{data_object.keys[0]}"
  # puts "iteration: #{iteration}"
  # puts "feature_path: #{feature_path.to_s.slice(0,300)}"
  # puts " "
  # If this is the first iteration it'll run through each item in the
  # top-level schema, once everything has been run-through the method
  # won't recurse again.
  if iteration.zero?
    # puts " "
    # puts "branch iteration.zero?"
    get_browser_keys(data_object["browsers"])
    seed_browser_data()
    @top_level_schema.each_with_index do |(key, value), index|
      # puts " "
      # puts "top level schema"
      # puts "Key: #{key}"
      # puts "Value: #{value}"
      # puts "Index: #{index}"
      iteration += 1
      feature_path = [key.to_s]
      # puts "pass feature_path into recursive function"
      # puts "feature_path: #{feature_path}"
      recursive_parse_browser_data_schema(data_object[key.to_s], iteration, feature_path)
    end
  # If the data object has the __compat key that means it's time to parse
  # the browser support.
  elsif data_object.has_key?("__compat")
    # puts " "
    # puts "branch data_object.has_key?('compat')"
    # data_object["__compat"]["support"].each_with_index do |(key, value), index|
    #   puts "Key: #{key}"
    #   puts "Value: #{value.to_s.slice(0,100)}"
    #   puts "Index: #{index}"
    # end

    # puts "FEATURE PATH: #{feature_path}"

    create_feature(
      feature_path.join("."), #name
      data_object["__compat"]["description"], # description
      data_object["__compat"]["mdn_url"], # mdn_url
      data_object["__compat"]["spec_url"], # spec_url
      data_object["__compat"]["status"], #status
      data_object["__compat"]["support"] #support object
    )

    if data_object.keys.length > 1
      # puts "DATA OBJECT KEYS > 1"
      # puts data_object.keys
      data_object.keys.each_with_index do |(key, value), index|
        if key == "__compat"
          next
        end

        new_feature_path = feature_path.dup
        new_feature_path.push(key)

        iteration += 1
        recursive_parse_browser_data_schema(data_object[key.to_s], iteration, new_feature_path)
      end
    end

    # Send the data to the browser_versions_supported method.
    # browser_versions_supported(data_object["__compat"]["support"])
  elsif !data_object.has_key?("__compat")
    iteration += 1
    data_object.each_with_index do |(key, value), index|
      # puts ""
      # puts ""
      # puts "data_object each with index #{index}"
      # puts "Key: #{key}"
      # puts "Value: #{value.to_s.slice(0,500)}"
      # puts "Index: #{index}"

      new_feature_path = feature_path.dup
      new_feature_path.push(key)

      iteration += 1
      recursive_parse_browser_data_schema(data_object[key.to_s], iteration, new_feature_path)
    end
  end
end

# This method prints the browser support info from the JSON.
def browser_versions_supported(data_object)
  puts " "
  puts "DATA OBJECT"
  puts data_object

  # @browser_keys.each do |browser_key|
  #   if data_object.key?(browser_key)
  #     puts " "

  #     # This can either be a Hash or an Array, depending on the specific case.
  #     # If it's an Array.
  #     if data_object[browser_key.to_s].kind_of?(Array)
  #       puts "Data: #{data_object[browser_key.to_s]}"
  #       data_object[browser_key.to_s].each_with_index do |info, index|
  #         info.keys.each do |key, value|
  #           # This should handle `version_added = nil` somehow.
  #           # Right now it just outputs a blank value, it should instead
  #           # say "unknown".
  #           puts "#{key}: #{info[key.to_s]}"
  #         end
  #         unless index + 1 == data_object[browser_key.to_s].size
  #           puts "--------"
  #         end
  #       end
  #     # If it's a Hash.
  #     elsif data_object[browser_key.to_s].kind_of?(Hash)
  #       puts "Data: #{data_object[browser_key.to_s]}"
  #       data_object[browser_key.to_s].keys.each do |key, value|
  #         puts "#{key.to_s}: #{data_object[browser_key.to_s][key.to_s]}"
  #       end
  #     end
  #   end
  # end
end

def create_feature(name, description=nil, mdn_url=nil, spec_url=nil, status=nil, support_object)
  # puts "CREATE FEATURE"
  # puts "support_object: #{support_object}"
  # puts "name: #{name}"
  # puts "Description: #{description}"
  # puts "mdn_url: #{mdn_url}"
  # puts "spec_url: #{spec_url}"
  # puts "Status: #{status}"

  if false
    Feature.create(
      name: name,
      description: description,
      mdn_url: mdn_url,
      spec_url: spec_url,
      deprecated: status["deprecated"],
      experimental: status["experimental"],
      standard_track: status["standard_track"],
      support: support_object
    )
  end
end

get_browser_keys(@data["browsers"])
seed_browser_data()
recursive_parse_browser_data_schema(@data, 0)
