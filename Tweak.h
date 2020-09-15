@interface NSObject (Undocumented)
+ (id)description;
@end

@interface __NSDictionaryM
+ (id)dictionary;
@end

@interface __NSCFString
@end

@interface CKConversationList
+ (id)sharedConversationList;
- (id)conversationForExistingChatWithGroupID:(id)arg1;
@end

@interface CKConversation : NSObject
- (id)messageWithComposition:(id)arg1;
- (void)sendMessage:(id)arg1 newComposition:(bool)arg2;
- (void)setLocalUserIsTyping:(_Bool)arg1;
@end

@interface CKComposition : NSObject
- (id)initWithText:(id)arg1 subject:(id)arg2;
- (id)compositionByAppendingMediaObject:(id)arg1;
@end

@interface CKMessage
@end

@interface CKMediaObject : NSObject
@end

@interface CKMediaObjectManager : NSObject
+ (id)sharedInstance;
- (id)mediaObjectWithFileURL:(id)arg1 filename:(id)arg2 transcoderUserInfo:(id)arg3 attributionInfo:(id)arg4 hideAttachment:(_Bool)arg5;
@end

@interface UIApplication (Undocumented)
+ (id)sharedApplication;
- (_Bool)launchApplicationWithIdentifier:(id)arg1 suspended:(_Bool)arg2;
@end

@interface NSConcreteNotification
- (id)object;
- (id)userInfo;
@end

@interface IMChat : NSObject {
	NSString *_identifier;
}
- (void)sendMessage:(id)arg1;
- (void)markAllMessagesAsRead;
- (void)sendMessageAcknowledgment:(long long)arg1 forChatItem:(id)arg2 withMessageSummaryInfo:(id)arg3 withGuid:(id)arg4;
@end

@interface IMChatRegistry
+ (id)sharedInstance;
- (id)chatForIMHandle:(id)arg1;
- (id)existingChatWithChatIdentifier:(id)arg1;
@end

@interface IMChatHistoryController
+ (id)sharedInstance;
- (void)loadMessageWithGUID:(id)arg1 completionBlock:(void(^)(id))arg2;
@end

@interface IMHandle : NSObject {
	NSString *_id;
}
- (id)initWithAccount:(id)arg1 ID:(id)arg2 alreadyCanonical:(_Bool)arg3;
@end

@interface IMMessageItem
@end

@interface IMMessage : NSObject {
	IMHandle *_subject;
}
@property(readonly, nonatomic) IMMessageItem *_imMessageItem;
+ (id)instantMessageWithText:(id)arg1 flags:(unsigned long long)arg2;
@end

@interface IMAccount : NSObject {
	NSString *_loginID;
}
@end

@interface IMAccountController : NSObject
+ (id)sharedInstance;
- (id)mostLoggedInAccount;
@end

@interface SBApplicationController
+ (id)sharedInstance;
- (id)applicationWithBundleIdentifier:(id)arg1;
@end

@interface SBApplicationProcessState
@end

@interface SBApplication
@property(readonly, nonatomic) SBApplicationProcessState *processState;
@end

@interface NSBundle (Undocumented)
+ (id)mainBundle;
@property (readonly, copy) NSString *bundleIdentifier;
@end
