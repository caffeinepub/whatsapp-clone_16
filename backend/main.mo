import Map "mo:core/Map";
import Time "mo:core/Time";
import Text "mo:core/Text";
import Runtime "mo:core/Runtime";
import List "mo:core/List";
import Principal "mo:core/Principal";
import MixinAuthorization "authorization/MixinAuthorization";
import AccessControl "authorization/access-control";

actor {
  type UserProfile = {
    username : Text;
    avatar : Text;
    status : Text;
    lastActive : Time.Time;
  };

  type Message = {
    sender : Principal;
    content : Text;
    timestamp : Time.Time;
  };

  type Conversation = {
    participants : [Principal];
    messages : [Message];
  };

  let accessControlState = AccessControl.initState();
  include MixinAuthorization(accessControlState);

  let userProfiles = Map.empty<Principal, UserProfile>();
  let conversations = Map.empty<Text, Conversation>();

  public query ({ caller }) func getCallerUserProfile() : async ?UserProfile {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only users can get their profile");
    };
    userProfiles.get(caller);
  };

  public shared ({ caller }) func saveCallerUserProfile(profile : UserProfile) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only users can save their profile");
    };
    userProfiles.add(caller, profile);
  };

  // registerUser is intentionally open to guests (no role check) because
  // a newly authenticated Internet Identity user starts as a guest and needs
  // to call this function to register themselves and obtain the #user role.
  // Anonymous principals are rejected implicitly by the MixinAuthorization
  // initialize flow; here we only block the anonymous principal explicitly.
  public shared ({ caller }) func registerUser(username : Text, avatar : Text, status : Text) : async () {
    if (caller.isAnonymous()) {
      Runtime.trap("Unauthorized: Anonymous principals cannot register");
    };

    let profile : UserProfile = {
      username;
      avatar;
      status;
      lastActive = Time.now();
    };

    userProfiles.add(caller, profile);
  };

  public shared ({ caller }) func sendMessage(conversationId : Text, content : Text) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only users can send messages");
    };

    let message : Message = {
      sender = caller;
      content;
      timestamp = Time.now();
    };

    let updatedConversation = switch (conversations.get(conversationId)) {
      case (null) {
        Runtime.trap("Conversation does not exist");
      };
      case (?conversation) {
        let isParticipant = do {
          var found = false;
          for (p in conversation.participants.vals()) {
            if (Principal.equal(p, caller)) {
              found := true;
            };
          };
          found
        };
        if (not isParticipant) {
          Runtime.trap("Unauthorized: You are not a participant in this conversation");
        };
        let messagesList = List.fromArray<Message>(conversation.messages);
        messagesList.add(message);
        {
          conversation with messages = messagesList.toArray();
        };
      };
    };

    conversations.add(conversationId, updatedConversation);
  };

  public shared ({ caller }) func updateStatus(status : Text) : async () {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only users can update their status");
    };

    switch (userProfiles.get(caller)) {
      case (null) {
        Runtime.trap("User not found");
      };
      case (?profile) {
        let updatedProfile = {
          profile with
          status;
          lastActive = Time.now();
        };
        userProfiles.add(caller, updatedProfile);
      };
    };
  };

  public query ({ caller }) func getUserProfile(target : Principal) : async UserProfile {
    // Admins can view any profile; users can view any profile (needed for messaging);
    // guests and anonymous principals are not allowed.
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only users can view profiles");
    };
    switch (userProfiles.get(target)) {
      case (null) {
        Runtime.trap("User not found");
      };
      case (?profile) { profile };
    };
  };

  // isUserOnline exposes only a boolean derived from a timestamp.
  // Any authenticated user (including guests with a real II principal) may call this.
  // Anonymous principals are blocked to prevent unauthenticated polling.
  public query ({ caller }) func isUserOnline(user : Principal) : async Bool {
    if (caller.isAnonymous()) {
      Runtime.trap("Unauthorized: Anonymous principals cannot query online status");
    };
    switch (userProfiles.get(user)) {
      case (null) { false };
      case (?profile) {
        Time.now() - profile.lastActive < 300_000_000_000
      };
    };
  };

  public query ({ caller }) func getAllUserProfiles() : async [(Principal, UserProfile)] {
    if (not (AccessControl.hasPermission(accessControlState, caller, #user))) {
      Runtime.trap("Unauthorized: Only users can list all profiles");
    };
    userProfiles.toArray();
  };
};
