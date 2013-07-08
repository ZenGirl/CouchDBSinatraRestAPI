require 'bundler/setup'

require 'sinatra/base'
require 'sinatra/assetpack'
require 'sinatra/support'
require 'sinatra/reloader' if :development

require 'yaml'
require 'awesome_print'
require 'rest-client'
require 'logger'
require 'json'

class App < Sinatra::Base

  base = File.dirname(__FILE__)
  set :root, base

  enable :logging

  # Local classes
  require File.join(base, 'api/wrapper.rb')
  require File.join(base, 'api/company_document.rb')

  configure :development do
    p 'Reloading'
    require 'sinatra/reloader'
    register Sinatra::Reloader
    set :logging, Logger::DEBUG
  end

  database_config = YAML.load_file(File.join(base, '/config/couchdb.yml'))
  database_environment = database_config[ENV['RACK_ENV'].to_s]
  set :server_path, "#{database_environment['protocol']}://#{database_environment['host']}:#{database_environment['port']}/#{database_environment['prefix']}"

  set :public_folder, File.dirname(__FILE__) + '/static'

  register Sinatra::AssetPack

  assets do
    serve '/files', from: 'app/files'
  end

  before do
    content_type 'application/json'
    RestClient.log = logger
  end

  helpers do
    def get_query_options(body)
      # Page size
      page_size = params[:page_size].nil? ? 20 : params[:page_size].to_i
      # Page number
      page_number = params[:page_number].nil? ? 1 : params[:page_number].to_i
      # Field=Value search options
      search_fields = {}
      params.each_pair do |key, value|
        next if [:id, :page_size, :page_number, :splat, :captures].include? key.to_sym
        search_fields[key] = value
      end
      # Return
      query = {
          :page_size => page_size,
          :page_number => page_number,
          :search_fields => search_fields
      }
      return Company::Wrapper.new([], query, body)
    end

    def to_params
      params = ''
      stack = []

      each do |k, v|
        if v.is_a?(Hash)
          stack << [k, v]
        else
          params << "#{k}=#{v}&"
        end
      end

      stack.each do |parent, hash|
        hash.each do |k, v|
          if v.is_a?(Hash)
            stack << ["#{parent}[#{k}]", v]
          else
            params << "#{parent}[#{k}]=#{v}&"
          end
        end
      end

      params.chop! # trailing &
      params
    end

    def skip(wrapper)
      page_number = wrapper.query[:page_number]
      page_number = 1 if page_number <= 0 or page_number > 100;
      (page_number-1) * limit(wrapper)
    end

    def limit(wrapper)
      page_size = wrapper.query[:page_size]
      page_size = 20 if page_size <= 0 or page_size > 100;
      page_size
    end

    def db_get_no_parse(path)
      RestClient.get(URI.escape("#{settings.server_path}/#{path}"), :content_type => :json, :accept => :json).to_str
    end

    def db_get(path)
      JSON.parse RestClient.get(URI.escape("#{settings.server_path}/#{path}"), :content_type => :json, :accept => :json).to_str
    end

    def db_post(path, body)
      JSON.parse RestClient.post URI.escape("#{settings.server_path}/#{path}"), body, :content_type => :json, :accept => :json
    end

    def db_put(path, body)
      RestClient.put URI.escape("#{settings.server_path}/#{path}"), body, :content_type => :json, :accept => :json
    end

    def db_delete(path)
      RestClient.delete URI.escape("#{settings.server_path}/#{path}"), :content_type => :json, :accept => :json
    end
  end

  # Function allows both get / post.
  def self.get_or_post(path, opts={}, &block)
    get(path, opts, &block)
    post(path, opts, &block)
  end

  get '/cleanup_views' do
    wrapper = Company::Wrapper.new([], [], {})
    wrapper.body = JSON.parse RestClient.post "#{settings.server_path}/_view_cleanup", {}
    wrapper.to_json
  end

  get '/show_views' do
    Company::Wrapper.new([], [], db_get('_all_docs?startkey="_design/"&endkey="_design0"&include_docs=true')).to_json
  end

  get '/recreate_views' do
    [Company::Document].each do |view|
      begin
        doc = db_get("_design/#{view.to_s}?_revs_info=true")
        db_delete("_design/#{view.to_s}?rev=#{doc['_rev']}")
      rescue RestClient::ResourceNotFound
        logger.warn "View not found: #{view}"
      end
    end
    Company::Wrapper.new([], [], db_post('', IO.read(File.join(base, 'designs/document_views.json')))).to_json
  end

  get '/document' do
    wrapper = get_query_options('')
    search_fields = wrapper.query[:search_fields]
    view = 'all'
    view = search_fields['view'] unless search_fields['view'].nil?
    url = "_design/Company::Document/_view/#{view}"
    query_string = ''
    Company::Document.attributes.each do |attribute|
      query_string += "key=\"#{search_fields[attribute]}\"&" if search_fields.has_key? attribute
    end
    if search_fields.has_key? 'reduce'
      query_string += 'reduce=true&group=true&'
    else
      query_string += "reduce=false&revs_info=true&skip=#{skip(wrapper)}&limit=#{limit(wrapper)}&"
    end
    url += '?' + query_string.chop
    wrapper.body = db_get(url)
    wrapper.to_json
  end

  get '/document/attributes' do
    wrapper = get_query_options('')
    wrapper.body = Company::Document.input_attributes
    wrapper.to_json
  end

  get '/document/:id' do
    get_query_options(db_get("#{params[:id]}?revs_info=true")).to_json
  end

  post '/document' do
    doc = Company::Document.new('app', 'kim')
    doc.load_from(params)
    if doc.valid?
      logger.debug 'Document is valid'
      result = db_post('', doc.to_json)
      get_query_options(result).to_json
    else
      logger.debug 'Document is invalid'
      wrapper = get_query_options('')
      wrapper.errors = doc.errors
      wrapper.to_json
    end
  end

  post '/document/:id ' do
    logger.debug ' POST ERROR '
    wrapper = get_query_options('')
    wrapper.errors = ['POST NOT ALLOWED WITH ID']
    wrapper.to_json
  end

  put '/document ' do
    logger.debug ' PUT bulk update '
  end

  put '/document/:id' do
    logger.debug "PUT [#{params[:id]}]"
    doc = db_get_no_parse("#{params[:id]}?revs_info=true")
    obj = Company::Document.new(nil, nil)
    obj.from_json!(doc)
    obj.load_from(params)
    if obj.valid?
      logger.debug 'Document is valid'
      obj.updated_at = Time.now
      result = db_put(params[:id], obj.to_json)
      get_query_options(result).to_json
    else
      logger.debug 'Document is invalid'
      wrapper = get_query_options('')
      wrapper.errors = obj.errors
      wrapper.to_json
    end
  end

  delete '/document' do
    logger.debug 'DELETE all '
    items = db_get('_design/Company::Document/_view/all?revs_info=true')
    items['rows'].each do |doc|
      begin
        item = db_get("#{doc['id']}?revs_info=true")
        logger.debug "item=[#{item}]"
        item['_revs_info'].each do |rev|
          logger.debug "Deleting [#{doc['id']}] Rev [#{rev['rev']}]"
          db_delete("#{doc['id']}?rev=#{rev['rev']}")
        end
      rescue RestClient::ResourceNotFound
        logger.warn "View not found: #{view}"
      end
    end
    wrapper = get_query_options('')
    wrapper.body = db_get('_design/Company::Document/_view/all?revs_info=true')
    wrapper.to_json
  end

  delete '/document/:id' do
    wrapper = get_query_options('')
    begin
      logger.debug "DELETE [#{params[:id]}]"
      doc = db_get("#{params[:id]}?revs_info=true")
      db_delete("#{params[:id]}?rev=#{doc['_rev']}")
      wrapper.body = db_get(params[:id])
    rescue RestClient::ResourceNotFound
      logger.warn "Item not found: #{params[:id]}"
    end
    wrapper.to_json
  end

end