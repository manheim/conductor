# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180315200001) do

  create_table "alternate_search_texts", force: :cascade do |t|
    t.integer  "message_id", limit: 8,                        null: false
    t.text     "text",       limit: 4294967295
    t.datetime "created_at",                    precision: 6, null: false
    t.datetime "updated_at",                    precision: 6, null: false
  end

  add_index "alternate_search_texts", ["message_id"], name: "message_id", unique: true, using: :btree
  add_index "alternate_search_texts", ["text"], name: "text_idx", type: :fulltext

  create_table "messages", force: :cascade do |t|
    t.text     "body",                limit: 4294967295
    t.text     "headers",             limit: 4294967295
    t.datetime "created_at",                             precision: 6,                 null: false
    t.datetime "updated_at",                             precision: 6,                 null: false
    t.string   "shard_id",            limit: 190,                      default: "0"
    t.datetime "succeeded_at",                           precision: 6
    t.integer  "processed_count",     limit: 4,                        default: 0
    t.datetime "processed_at",                           precision: 6
    t.datetime "last_failed_at",                         precision: 6
    t.text     "last_failed_message", limit: 65535
    t.integer  "response_code",       limit: 4
    t.text     "response_body",       limit: 65535
    t.boolean  "needs_sending",                                        default: false
  end

  add_index "messages", ["created_at"], name: "index_messages_on_created_at", using: :btree
  add_index "messages", ["last_failed_at"], name: "index_messages_on_last_failed_at", using: :btree
  add_index "messages", ["needs_sending", "shard_id"], name: "index_on_needs_sending_and_shard_id", using: :btree
  add_index "messages", ["processed_count"], name: "index_messages_on_processed_count", using: :btree
  add_index "messages", ["shard_id"], name: "index_messages_on_shard_id", using: :btree
  add_index "messages", ["succeeded_at"], name: "index_messages_on_succeeded_at", using: :btree

  create_table "runtime_settings", force: :cascade do |t|
    t.text     "settings",   limit: 16777215
    t.datetime "created_at",                  precision: 6, null: false
    t.datetime "updated_at",                  precision: 6, null: false
  end

  create_table "search_texts", force: :cascade do |t|
    t.integer  "message_id", limit: 8,                        null: false
    t.text     "text",       limit: 4294967295
    t.datetime "created_at",                    precision: 6, null: false
    t.datetime "updated_at",                    precision: 6, null: false
  end

  add_index "search_texts", ["message_id"], name: "message_id", unique: true, using: :btree
  add_index "search_texts", ["text"], name: "text_idx", type: :fulltext

end
