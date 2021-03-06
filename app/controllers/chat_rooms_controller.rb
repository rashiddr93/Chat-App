#
# ChatRoomsController
#
# @author sufinsha
#
class ChatRoomsController < ApplicationController
  include ChatRoomInitializer
  around_action :set_time_zone
  before_action :current_user_chat_rooms, only: [:create, :unread_messages]

  def show
    @chat_room = ChatRoom.includes(
      chat_room_users: :user, messages: :user
    ).find_by(id: params[:id])
  end

  def create
    initialize_chat_room
    @user = @chat_room.chat_room_users.where.not(user_id: current_user.id).first.user
    find_first_message_page
    find_last_seen_message(@chat_room.id)
    set_read_flag
    broadcast_read_status
    render partial: 'show', locals: {
      messages: @messages,
      user: @user,
      chat_room: @chat_room,
      last_seen_message: @last_seen_message
    }
  end

  # GET #chat_room_messages /chat_rooms
  def chat_room_messages
    find_next_message_page(params[:last_message_id])
    find_last_seen_message(params[:chat_room_id])
    if @messages.blank?
      render json: { last_page: true } if @messages.blank?
    else
      html_code = render_to_string(
        '_messages',
        formats: [:html],
        layout: false,
        locals: { messages: @messages, last_seen_message: @last_seen_message, last_page: false }
      )
      render json: { html_code: html_code, last_message_id: @messages.first.id }
    end
  end

  # GET #delete_conversation /chat_rooms
  def delete_conversation
    current_user.user_messages.joins(:message).where(messages: { chat_room_id: params[:chat_room_id] }).destroy_all
    render json: { status: 'success' }
  end

  # GET #upload_attachment /chat_rooms
  def upload_attachment
    @message = Message.create(
      user_id: current_user.id,
      chat_room_id: params[:chat_room_id],
      attachment: params[:image]
    )
    broadcast_attachment
  end

  private

  # broadcast attachment
  def broadcast_attachment
    @message.chat_room.users.each do |reciever|
      ActionCable.server.broadcast(
        "messages_channel_#{reciever.id}",
        type: 'attachment',
        content_type: @message.attachment.file.content_type,
        url: @message.attachment.url,
        user_id: current_user.id,
        chat_room_uuid: @message.chat_room.uuid
      )
    end
  end

  # broadcast read status
  def broadcast_read_status
    ActionCable.server.broadcast(
      "messages_channel_#{params[:user_id]}",
      type: 'read_status',
      user_id: current_user.id
    )
  end

  # set read flag to true
  def set_read_flag
    current_user.user_messages
                .joins(:message)
                .where(messages: { chat_room_id: @chat_room.id })
                .update_all(is_read: true)
  end

  # find_last_seen_message
  def find_last_seen_message(chat_room_id)
    @last_seen_message = Message.where(chat_room_id: chat_room_id)
                                .joins(:user_messages)
                                .where(messages: { user_id: current_user }, user_messages: { is_read: true })
                                .where.not(user_messages: { user_id: current_user.id })
                                .select('messages.id, user_messages.updated_at').last
  end

  # find first user message page
  def find_first_message_page
    @messages = current_user.messages.where(chat_room_id: @chat_room.id)
                            .includes(:user).order('messages.id DESC')
                            .page(1).per(10).reverse
  end

  # find next user message page after a particular id
  def find_next_message_page(last_message_id)
    @messages = current_user.messages
                            .where(chat_room_id: params[:chat_room_id])
                            .where('messages.id < ?', last_message_id)
                            .includes(:user).order('messages.id DESC')
                            .page(1).per(10).reverse
  end
end
