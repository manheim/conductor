class MessagesController < ApplicationController

  def create
    MessageCreator.new({
      params: params,
      request: request,
      settings: Settings.to_hash
    }).create

    render status: 200, text: ''
  end

end
