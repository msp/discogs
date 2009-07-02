# Core API wrapper class.

require 'uri'
require 'net/http'
require 'rexml/document'
require 'zlib'
require 'stringio'

require File.dirname(__FILE__) + "/resource"

class Discogs::Wrapper

  @@root_host = "http://www.discogs.com"

  attr_reader :api_key

  def initialize(api_key=nil)
    @api_key = api_key
  end

  def get_release(id)
    query_and_build "release/#{id}", Discogs::Release
  end

  def get_artist(name)
    query_and_build "artist/#{name}", Discogs::Artist
  end

  def get_label(name)
    query_and_build "label/#{name}", Discogs::Label
  end

 private

  def query_and_build(path, klass)
    data = query_api(path)
    resource = klass.send(:new, data)
    resource.build!
  end

  # Queries the API and handles the response.
  def query_api(path, params={})
    response = make_request(path, params)

    raise_unknown_resource(path) if response.code == "404"
    raise_invalid_api_key if response.code == "400"

    # Unzip the response data.
    inflated_data = Zlib::GzipReader.new(StringIO.new(response.body))
    inflated_data.read
  end

  # Generates a HTTP request and returns the response.
  def make_request(path, params={})
    uri = build_uri(path, params)

    request = Net::HTTP::Get.new(uri.path + "?" + uri.query)
    request.add_field("Accept-Encoding", "gzip,deflate")

    response = Net::HTTP.new(uri.host).start do |http|
      http.request(request)
    end
  end

  def build_uri(path, params={})
    parameters = { :f => "xml", :api_key => @api_key }.merge(params)
    querystring = "?" + parameters.map { |key, value| "#{key}=#{value}" }.join("&")

    URI.parse(File.join(@@root_host, path + querystring))
  end

  def raise_invalid_api_key
    raise Discogs::InvalidAPIKey, "Invalid API key: #{@api_key}"
  end

  def raise_unknown_resource(path='')
    raise Discogs::UnknownResource, "Unknown Discogs resource: #{path}"
  end

end
