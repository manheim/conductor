require "administrate/base_dashboard"

class MessageDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    shard_id: Field::Text,
    body: Field::Text,
    headers: Field::Text,
    succeeded_at: Field::DateTime,
    processed_count: Field::Number,
    processed_at: Field::DateTime,
    last_failed_at: Field::DateTime,
    last_failed_message: Field::Text,
    response_code: Field::Number,
    response_body: Field::Text,
    needs_sending: Field::Boolean,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = [
    :id,
    :shard_id,
    :body,
    :headers,
    :succeeded_at,
    :processed_count,
    :processed_at,
    :last_failed_at,
    :response_code,
    :needs_sending,
    :created_at,
  ]

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = [
    :id,
    :shard_id,
    :succeeded_at,
    :processed_count,
    :processed_at,
    :last_failed_at,
    :last_failed_message,
    :response_code,
    :response_body,
    :needs_sending,
    :created_at,
    :updated_at,
    :headers,
    :body,
  ]

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = [
    :body,
    :headers,
    :shard_id,
    :needs_sending
  ]

  # Overwrite this method to customize how messages are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(message)
  #   "Message ##{message.id}"
  # end
end
