class MessagesApiController < ApplicationController
  include Concerns::BasicAuthentication

  before_action :set_message, only: [:show, :update]

  FIELDS_WHICH_CAN_BE_UPDATED = [ 'needs_sending' ]

  def show
    logger.info "showing #{message_id}"
    if @message.nil?
      logger.info "show call rejected, could not find message with id #{message_id}"
      render nothing: true, status: 404
    else
      render json: @message
    end
  end

  def update
    logger.info "update call for message #{message_id} with data #{@message_params}"
    if @message.nil?
      logger.info "update call rejected, could not find message record for id #{message_id}"
      render nothing: true, status: 404
    elsif message_params_invalid
      logger.info "Bulk update call with invalid param data: #{message_data}"
      render nothing: true, status: 400
    elsif session[:user_role] == 'readonly_user'
      logger.info "update call rejecting update due to user being readonly"
      render nothing: true, status: 401
    elsif message_params == {}
      logger.info "update without data, short circuiting"
      render nothing: true, status: 400
    elsif @message.update(message_params)
      logger.debug "update successful"
      render nothing: true, status: 204
    else
      logger.error "update was not successful of message #{@message.id} with data #{message_params}"
      render nothing: true, status: 400
    end
  end

  def bulk_update
    ids, data = bulk_update_params
    if message_params_invalid
      logger.info "Bulk update call with invalid param data: #{message_data}"
      render nothing: true, status: 400
    elsif ids == []
      logger.info "Bulk update call without ids, rejecting"
      render nothing: true, status: 400
    elsif data.nil? || data == {}
      logger.info "Bulk update call without data, rejecting"
      render nothing: true, status: 400
    elsif ids.length > 1000
      logger.info "Bulk update with too many ids [#{ids.length}], rejecting"
      render nothing: true, status: 400
    elsif session[:user_role] == 'readonly_user'
      logger.info "update call rejecting update due to user being readonly"
      render nothing: true, status: 401
    else
      query = Message.where(id: ids)
      count = query.count
      if query.count != ids.length
        logger.info "Bulk update: retrieved record count does not match #{ids.length}|#{count}, short circuiting"
        render nothing: true, status: 400
      else
        logger.info "Bulk updating #{count} records with #{data}"
        Message.transaction do
          query.find_each do |message|
            message.update! data
            logger.debug "Bulk update of message #{message.id}"
          end
        end
        render nothing: true, status: 204
      end
    end
  rescue ActiveRecord::ActiveRecordError => ex
    logger.error "bulk updating failed: #{ex}"
    render nothing: true, status: 400
  end

  def search
    logger.info "Searching: start: #{page_start}; page_size_limit: #{page_size_limit}; params: #{search_params}"
    query = Message.page(1).per(page_size_limit)
    if page_start
      query = query.where('id > ?', page_start)
    end
    if search_params['created_after']
      query = query.where('created_at > ?', search_params['created_after'])
    end
    if search_params['created_before']
      query = query.where('created_at <= ?', search_params['created_before'])
    end
    if search_params['text']
      ids = MessageSearcher.new({
        max_full_text_search_results: page_size_limit,
        search_term: search_params['text']
      }).message_ids
      query = query.where(id: ids)
    end
    if search_params['with_fields'] && search_params['with_fields'] == "all"
      render json: { items: query.all.to_a }, status: 200
    else
      items = query.all.map(&:id).map{|id| { id: id } }
      render json: { items: items }, status: 200
    end
  end

  private

  def set_message
    @message = Message.find message_id
  rescue ActiveRecord::RecordNotFound
    @message = nil
  end

  def message_id
    params['id']
  end

  def message_params
    filter_update_fields message_data
  end

  def message_data
    return @message_data if !@message_data.nil?
    request.body.rewind
    body = request.body.read
    @message_data ||= JSON.parse(body)
  rescue JSON::ParserError
    logger.error "Could not parse json: #{body}"
    return nil
  end

  def message_params_invalid
    return true if message_data.class != Hash
    return true if message_data['data'] != nil && message_data['data'].class != Hash
    false
  end

  def search_params
    {}.tap do |r|
      r['created_after'] = params['created_after'].to_datetime if params['created_after']
      r['created_before'] = params['created_before'].to_datetime if params['created_before']
      r['text'] = params['text'] if params['text']
      r['with_fields'] = params['with_fields'] if params['with_fields']
    end
  end

  def bulk_update_params
    return [nil, nil] if message_data.nil?
    update_data = filter_update_fields message_data['data']
    [ message_data['items'], update_data ]
  end

  def filter_update_fields data
    return nil if data.nil?
    data.select { |k,v| FIELDS_WHICH_CAN_BE_UPDATED.include? k }
  end

  def page_size_limit
    [ (params['limit'] || 25).to_i, 500 ].min
  end

  def page_start
    params['start']
  end

end
