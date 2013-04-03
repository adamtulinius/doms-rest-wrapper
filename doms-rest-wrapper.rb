#!/usr/bin/env ruby

require 'rubygems'
require 'bundler'
Bundler.require

doms_webservice = "http://alhena:7880/centralWebservice-service/central/?wsdl"
doms_username = "fedoraAdmin"
doms_password = "fedoraAdminPass"

client = Savon.client(wsdl: doms_webservice, basic_auth: [doms_username, doms_password])

set :bind, '0.0.0.0'
set :static, true

public_dir = if ARGV.length > 0
  set :public_dir, Proc.new { File.join(root, ARGV[0])}
end


get '/' do
  send_file File.expand_path('index.html', settings.public_folder)
end

get '/objects/:uuid' do |uuid|
  response = client.call(:get_object_profile, message: {pid: uuid})
  object = response.body[:get_object_profile_response][:object_profile]
  object.to_json
end

get '/objects/:uuid/:datastream' do |uuid, datastream|
  datastream_response = client.call(:get_datastream_contents, message: {pid: uuid, datastream: datastream})
  datastream_response.body[:get_datastream_contents_response][:string]
end

get '/search' do
  query = params[:q]
  query = "*" if query.length == 0

  offset = limit_value(params[:offset], 0, nil, nil)
  limit = limit_value(params[:limit], 25, nil, 100)

  response = client.call(:find_objects, message: {query: query, offset: offset, pageSize: limit})
  hit_count = response.body[:find_objects_response][:search_result][:hit_count]
  search_results = response.body[:find_objects_response][:search_result][:search_result]
  if search_results.class == {}.class # sorry :-)
    search_results = [search_results]
  end

  search_results ||= []

  search_results.each do |result|
    result["id"] = "/objects/#{result[:pid]}"
  end

  {search_results: search_results, hit_count: hit_count, query: query, limit: limit, offset: offset}.to_json
end

def limit_value(value, default, min=nil, max=nil)
  value = nil if value == ""
  r = value || default
  r = r.to_i

  if min and r < min
    min
  elsif max and r > max
    max
  else
    r
  end
end

