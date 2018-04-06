require 'will_paginate/array'

module Admin
  class MessagesController < Admin::ApplicationController

    before_filter :redirect_unless_admin, only: [:edit, :new, :destroy]
    before_filter :authorize_admin, only: [:update, :create]

    def index
      Octopus.using(read_from_database) do

        search_term = params[:search].to_s.strip

        resources = if params[:view] == "most_failing"
                      load_most_failing_messages
                    else
                      load_messages(search_term)
                    end

        page = Administrate::Page::Collection.new(dashboard, order: order)

        render locals: {
          resources: resources,
          search_term: search_term,
          page: page
        }
      end
    end

    protected

    def load_most_failing_messages
      limit = params[:limit] ? params[:limit].to_i : 10
      UnsentWatcher.new.most_failing_unsent_messages(limit)
    end

    def load_messages(search_term)
      page_size = params[:limit] ? params[:limit].to_i : 100

      query = Message.order("id" => "desc")

      if search_term.present?
        ids = MessageSearcher.new({
          max_full_text_search_results: Settings.max_full_text_search_results,
          search_term: search_term
        }).message_ids
        query = query.where(id: ids)
      end

      query.limit(page_size)
    end

    def redirect_unless_admin
      redirect_to '/admin/messages', flash: {error: "You are not authorized to perform this action" }  unless session[:user_role] == "admin"
    end

    def authorize_admin
      render(status: 401, text: "") unless session[:user_role] == "admin"
    end
  end
end
