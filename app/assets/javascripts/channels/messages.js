// Create message channel
CreateMessageChannel = function() {
  App.messages = App.cable.subscriptions.create({
    channel: "MessagesChannel"
  }, {
    connected: function() {},
    disconnected: function() {},
    received: function(data) {
      var currentUserId = $('.message-textarea').data('current-user-id');
      if(data['type'] == 'message'){
        var activeChatRoom = $('.message-container').data('chat-room-uuid');
        if (data['user_id'] != currentUserId){
          appendReceivedMessage(data['message'], data['chat_room_uuid']);
          if (activeChatRoom != data['chat_room_uuid']){
            appendBadge(data['user_id']);
          }
        }
        else{
          appendSendMessage(data['message'], data['chat_room_uuid']);
        }  
        scrollDown();
      }
      else{
        if (data['user_id'] == currentUserId){
          return;
        }
        var message = '<div class="col-lg-12 msgbody"><span>' + data['user'] + ': </span><span>' + ' is typing' + '</span></div>';
        var $isTyping = $('.is-typing-' + data['chat_room_uuid']);
        $isTyping.show();
        $isTyping.html(message);
        $isTyping.delay(2000).hide(0);
      }
    },
    speak: function(message, roomId) {
      return this.perform('speak', {
        message: message,
        room_id: roomId
      });
    },
    isTyping: function(roomId) {
      return this.perform('typing?', {
        room_id: roomId
      });
    }

  });
};

// On keypress sent message if enter key
// else sent is-typing status
$(document).on('keypress', '[data-behavior~=room-speaker]', function(event) {
  roomId = $(this).data('room-uuid');
  if (event.keyCode === 13) {
    if (event.target.value == ''){
      event.preventDefault();
      return;
    }
    App.messages.speak(event.target.value, roomId);
    event.target.value = "";
    event.preventDefault();
  }
  else{
    App.messages.isTyping(roomId);
  }
});

// append badge
function appendBadge(userId){
  var chatRoomLink = $('.chat-room-link-' + userId);
  var messageCount = chatRoomLink.data('message-count') + 1;
  chatRoomLink.data('message-count', messageCount);
  var badge = '<span class="badge message-badge">' + messageCount + '</span>'
  chatRoomLink.html('Message ' + badge);
}

// scrollDown
function scrollDown(){
  var wtf    = $('.messages');
  var height = wtf[0].scrollHeight;
  wtf.scrollTop(height);
}

// append received message to chat room
function appendReceivedMessage(messageContent, chatRoomuuid){
  var imageSrc = $('.message-container').data('user-pic-url');
  var message = '<div class="col-lg-12 message-content"><div class="col-lg-12 message-content message-content-receiver"><span><img class="img-circle" src="' + imageSrc + '" alt="Default smallthumb"></span><span class="received-message">' + messageContent + '</span></div></div></div>';
  $('.message-container-' + chatRoomuuid).append(message);
}

// append sent message to chat room
function appendSendMessage(messageContent, chatRoomuuid){
  var imageSrc = $('.user-profile-pic').attr('src');
  var message = '<div class="col-lg-12 message-content"><div class="col-lg-12 message-content message-content-sender"><span class="send-message">' + messageContent + '</span><span><img class="img-circle" src="' + imageSrc + '" alt="Default smallthumb"></span></div></div>';
  $('.message-container-' + chatRoomuuid).append(message);
}