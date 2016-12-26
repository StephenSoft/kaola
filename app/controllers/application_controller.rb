class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  #skip_before_action :verify_authenticity_token, if: :json_request?
  skip_before_filter :verify_authenticity_token, :if => Proc.new { |c| c.request.format == 'application/json' }

  after_filter :cors_set_access_control_headers
  
  before_filter :crud_json_check
  
  def crud_json_check
     if Rails.env == "production"
       redirect_to "/500.html" unless request.format == 'application/json'
     end
  end

  def cors_set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'POST, GET, PUT, DELETE, OPTIONS'
    headers['Access-Control-Allow-Headers'] = 'Origin, Content-Type, Accept, Authorization, Token'
    headers['Access-Control-Max-Age'] = "1728000"
    headers['Access-Control-Allow-Credentials'] = true
    headers['X-Frame-Options'] = "ALLOWALL"
  end


  def set_process_name_from_request
    $0 = request.path[0,16]
  end

  def unset_process_name_from_request
    $0 = request.path[0,15] + "*"
  end

  def error_log(msg)
    File.open("log/scm-error.log","a") {|f| f.puts msg.to_s}
  end

  around_filter :exception_catch
  def exception_catch
    begin
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Credentials'] = true
      headers['Access-Control-Allow-Methods'] = 'POST, PUT, OPTIONS, GET'
      headers['X-Frame-Options'] = "ALLOWALL"
      yield
    rescue  Exception => err
      error_log "\nInternal Server Error: #{err.class.name}, #{Time.now}"
      error_log "#{request.path}  #{request.params}"
      err_str = err.to_s
      error_log err_str
      err.backtrace.each {|x| error_log x}
      if Rails.env == "production"
        render_error("#{request.path}出错了: #{err.class}")
      else
        render_error("#{request.path}出错了: #{err_str}")
      end
    end
  end

  def render_error(error, error_msg=nil, hash2=nil)
    hash = {:error => error}
    hash.merge!({:error_msg => error_msg}) if error_msg
    hash.merge!(hash2) if hash2
    render :status => 400, :json => hash.to_json
  end
  
  before_action :set_search_params, only: [:index]
  
  def set_search_params
    default_page_count = 100
    default_page_count = 10 if params[:many]
    @page_count = params[:per] || default_page_count
    @page = params[:page].to_i
    @order = params[:order]
    if @page<0
      @page = -@page
      @order = "created_at asc" if @order.nil?
      @order = @order.split(",").map do |x|
        if x.match(" desc")
          x.sub!(" desc"," asc")
        elsif x.match(" asc")
          x.sub!(" asc"," desc")
        end
        x
      end.join(",")
    end
  end
  
  def check_rawsql_json
    raise "raw_sql needs json output" unless request.format == 'application/json'
  end
  
  
  
  def do_search
    @list = @model_clazz.order(@order)
    if params[:s]
      check_search_param_exsit(params[:s].to_hash, @model_clazz)
      like_search
      date_search
      range_search
      in_search
      cmp_search
      equal_search
    end
    @count = @list.count if params[:count]=="1"
    @list = @list.page(@page).per(@page_count)
	  if params[:many] && params[:many].size>1
      @many = {}
	    params[:many].split(",").each do |x|
        @many[x] = @model_clazz.many_caches(x, @list)
      end
    end
    @belong_names = @model_clazz.belong_names
    @belongs = @model_clazz.belongs_to_multi_get(@list)
    @list
  end
  

  def equal_search
    return unless params[:s]
    query = {}
    query.merge!(simple_query(params[:s]))
    @list = @list.where(query) 
    with_dot_query(params[:s]).each do |k,v|
      model, field = k.split(".")
      hash = {(model.pluralize) => { field => v}}
      @list = @list.joins(model.to_sym).where(hash)
    end
    with_comma_query(params[:s]).each do |k,v|
      keys = k.split(",")
      t = @model_clazz.arel_table
      arel = t[keys[0].to_sym].eq(v)
      keys[1..-1].each{|key| arel = arel.or(t[key.to_sym].eq(v))}
      @list = @list.where(arel)
    end
  end

  def like_search
    return unless params[:s][:like]
    simple_query(params[:s][:like]).each {|k,v| @list = @list.where("#{k} like ?", like_value(v))}
    with_dot_query(params[:s][:like]).each do |k,v|
      model, field = k.split(".")
      @list = @list.joins(model.to_sym)
      @list = @list.where("#{model.pluralize}.#{field} like ?", like_value(v))
    end
    with_comma_query(params[:s][:like]).each do |k,v|
      keys = k.split(",")
      vv = like_value(v)
      t = @model_clazz.arel_table
      arel = t[keys[0].to_sym].matches(vv)
      keys[1..-1].each{|key| arel = arel.or(t[key.to_sym].matches(vv))}
      @list = @list.where(arel)
    end
    params[:s].delete(:like)
  end
  
  def like_value(v)
    return v if v.index("%") || v.index("_")
    "%#{v}%"
  end

  def date_search
    return unless params[:s][:date]
    simple_query(params[:s][:date]).each do |k,v|
      arr = v.split(",")
      if arr.size==1
        day = DateTime.parse(arr[0])
        @list = @list.where(k => day.beginning_of_day..day.end_of_day)
      elsif arr.size==2
        day1 = DateTime.parse(arr[0])
        day2 = DateTime.parse(arr[1])
        @list = @list.where(k => day1.beginning_of_day..day2.end_of_day)
      else
        logger.warn("date search 错误: #{k},#{v}")
      end
    end
    with_dot_query(params[:s][:date]).each do |k,v|
      model, field = k.split(".")
      @list = @list.joins(model.to_sym)
      arr = v.split(",")
      if arr.size==1
        day = DateTime.parse(arr[0])
        hash = {(model.pluralize) => { field => day.beginning_of_day..day.end_of_day}}
        @list = @list.where(hash)
      elsif arr.size==2
        day1 = DateTime.parse(arr[0])
        day2 = DateTime.parse(arr[1])
        hash = {(model.pluralize) => { field => day1.beginning_of_day..day2.end_of_day}}
        @list = @list.where(hash)
       else
        logger.warn("date search 错误: #{k},#{v}")
      end
    end
    params[:s].delete(:date)
  end

  def range_search
    return unless params[:s][:range]
    simple_query(params[:s][:range]).each do |k,v|
      arr = v.split(",")
      if arr.size==1
        v1 = arr[0].to_f
        operator = (v[0]==","?  "<=" : ">=")
        @list = @list.where("#{k} #{operator} ?", v1)
      elsif arr.size==2
        v1 = arr[0].to_f
        v2 = arr[1].to_f
        @list = @list.where(k => v1..v2)
      else
        logger.warn("range search 错误: #{k},#{v}")
      end
    end
    with_dot_query(params[:s][:range]).each do |k,v|
      model, field = k.split(".")
      @list = @list.joins(model.to_sym)
      arr = v.split(",")
      if arr.size==1
        v1 = arr[0].to_f
        operator = (v[0]==","?  "<=" : ">=")
        @list = @list.where("#{model.pluralize}.#{field} #{operator} ?", v1)
      elsif arr.size==2
        v1 = arr[0].to_f
        v2 = arr[1].to_f
        hash = {(model.pluralize) => { field => v1..v2}}
        @list = @list.where(hash)
      else
        logger.warn("range search 错误: #{k},#{v}")
      end
    end
    params[:s].delete(:range)      
  end   

  def in_search
    return unless params[:s][:in]
    simple_query(params[:s][:in]).each do |k,v|
      arr = v.split(",")
      @list = @list.where("#{k} in (?)", arr)
    end
    with_dot_query(params[:s][:in]).each do |k,v|
      model, field = k.split(".")
      @list = @list.joins(model.to_sym)
      arr = v.split(",")
      @list = @list.where("#{model.pluralize}.#{field} in (?)", arr)
    end
    params[:s].delete(:in)      
  end 

  def cmp_search
    return unless params[:s][:cmp]
    simple_query(params[:s][:cmp]).each do |key,v|
      ["!=","<=",">=","=","<",">"].each do |op|
        if key.match(op)
          arr = key.split(op)
          next if arr.size != 2
          @list = @list.where("#{arr[0]} #{op} #{arr[1]}")
          break
        end
      end
    end
    params[:s].delete(:cmp)      
  end 
  
  def with_dot_query(hash)
    hash.select{|k,v| k.index(".")}
  end
  
  def with_comma_query(hash)
    hash.select{|k,v| k.index(",")}
  end

  def simple_query(hash)
    hash.select{|k,v| !k.index(".") && !k.index(",")}
  end
  
  
  def check_search_param_exsit(hash,clazz)
    attrs = clazz.attribute_names
    %w{like date range in cmp}.each do |op|
      next unless hash[op]
      hash[op].each{|k,v| check_keys_exist(k, attrs, clazz)}
      hash.delete(op)
    end
    hash.each{|k,v| check_keys_exist(k, attrs, clazz)}
  end
  
  def check_keys_exist(keys, attrs, clazz)
    if keys.index(",")
      keys.split(",").each{|x| check_field_exist(x, attrs)}
    elsif keys.index(".")
      model, field = keys.split(".")
      check_field_exist(model+"_id", attrs)
      clazz_name = clazz.get_belongs_class_name(model)
      check_field_exist(field, Object.const_get(clazz_name).attribute_names)
      #TODO: 跨库的join查询，数据库不支持
    else
      check_field_exist(keys, attrs)
    end
  end
  
  def check_field_exist(field, attrs)
    find = attrs.find{|x| x==field}
    raise "field:#{field} doesn't exists." unless find
  end
  
  
end
