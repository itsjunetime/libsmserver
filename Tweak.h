@interface NSObject (Undocumented)
@end

@interface __NSCFString
@end

@interface CKConversationList
+ (id)sharedConversationList;
- (id)conversationForExistingChatWithGroupID:(id)arg1;
@end

@interface CKComposition : NSObject
- (id)initWithText:(id)arg1 subject:(id)arg2;
- (id)compositionByAppendingMediaObject:(id)arg1;
@end

@interface CKConversation : NSObject
- (id)messageWithComposition:(id)arg1;
- (void)sendMessage:(id)arg1 newComposition:(bool)arg2;
@end

@interface CKMediaObject : NSObject
@end

@interface CKMediaObjectManager : NSObject
+ (id)sharedInstance;
- (id)mediaObjectWithFileURL:(id)arg1 filename:(id)arg2 transcoderUserInfo:(id)arg3 attributionInfo:(id)arg4 hideAttachment:(_Bool)arg5;
@end

@interface IMDaemonController
+ (id)sharedController;
- (BOOL)connectToDaemon;
@end

@interface IMPinnedConversationsController
- (NSOrderedSet *)pinnedConversationIdentifierSet;
@end

@interface UIApplication (Undocumented)
+ (id)sharedApplication;
- (_Bool)launchApplicationWithIdentifier:(id)arg1 suspended:(_Bool)arg2;
@end

@interface NSConcreteNotification
- (id)object;
- (id)userInfo;
@end

@interface NSDistributedNotificationCenter
+ (id)defaultCenter;
@end

@interface IMItemsController : NSObject
- (id)_itemForGUID:(id)arg1;
@end

@interface IMChat : IMItemsController {
	NSString *_identifier;
}
- (void)sendMessage:(id)arg1;
- (void)markAllMessagesAsRead;
- (void)sendMessageAcknowledgment:(long long)arg1 forChatItem:(id)arg2 withMessageSummaryInfo:(id)arg3;
- (void)sendMessageAcknowledgment:(long long)arg1 forChatItem:(id)arg2 withAssociatedMessageInfo:(id)arg3;
- (void)remove;
- (NSArray *)chatItems;
- (id)messageForGUID:(id)arg1;
- (id)messageItemForGUID:(id)arg1;
- (void)loadMessagesUpToGUID:(id)arg1 date:(id)arg2 limit:(unsigned long long)arg3 loadImmediately:(BOOL)arg4;
@end

@interface IMItem
- (NSString *)guid;
@end

@interface IMTranscriptChatItem : NSObject
- (NSString *)guid;
@end

@interface IMTextMessagePartChatItem : IMTranscriptChatItem
@end

@interface IMFileTransferCenter
@end

@interface IMFileTransfer : NSObject
- (NSString *)guid;
@end

@interface IMChatRegistry
+ (id)sharedInstance;
- (id)chatForIMHandle:(id)arg1;
- (id)existingChatWithChatIdentifier:(id)arg1;
- (id)_chatsWithMessageGUID:(id)arg1;
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

@interface IMMessageItem : NSObject
- (id)_initWithItem:(id)arg1 text:(id)arg2 index:(long long)arg3 messagePartRange:(NSRange)arg4 subject:(id)arg5;
- (NSString *)subject;
- (NSAttributedString *)body;
- (id)sender;
@end

@interface IMMessage : NSObject {
	IMHandle *_subject;
}
+ (id)instantMessageWithText:(id)arg1 flags:(unsigned long long)arg2;
+ (id)instantMessageWithText:(id)arg1 flags:(unsigned long long)arg2 threadIdentifier:(id)arg3;
- (NSString *)guid;
@end

@interface IMAccount : NSObject {
	NSString *_loginID;
}
@end

@interface IMAccountController : NSObject
+ (id)sharedInstance;
- (id)activeIMessageAccount;
- (IMAccount *)activeSMSAccount;
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
