#import <MRYIPCCenter.h>
#import "substrate.h"
#import "Tweak.h"

@interface SMServerIPC : NSObject
@end

@implementation SMServerIPC {
	MRYIPCCenter* _center;
}

+ (instancetype)sharedInstance {
	static dispatch_once_t onceToken = 0;
	__strong static SMServerIPC* sharedInstance = nil;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
	});
	return sharedInstance;
}

- (instancetype)init {
	if ((self = [super init])) {
		_center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserver"];
		[_center addTarget:self action:@selector(sendText:)];
		[_center addTarget:self action:@selector(setAllAsRead:)];
		[_center addTarget:self action:@selector(getPinnedChats)];
		[_center addTarget:self action:@selector(launchSMS)];
		[_center addTarget:self action:@selector(checkIfRunning:)];
		//[_center addTarget:self action:@selector(sendReaction:)];
	}
	return self;
}

- (void)sendText:(NSDictionary *)vals {
	/// You have to run this on main thread to do the `mediaObjectWithFileURL` bit
	dispatch_async(dispatch_get_main_queue(), ^{
		IMDaemonController* controller = [%c(IMDaemonController) sharedController];

		if ([controller connectToDaemon]) {
			NSArray* attachments = vals[@"attachment"];
			NSString* body = vals[@"body"];
			NSString* address = vals[@"address"];
			NSString* sub = vals[@"subject"];
			
			NSAttributedString* text = [[NSAttributedString alloc] initWithString:body];
			NSAttributedString* subject = [[NSAttributedString alloc] initWithString:sub];

			/*
			IMChatRegistry* registry = [%c(IMChatRegistry) sharedInstance];
			IMChat* chat = [registry existingChatWithChatIdentifier:(__NSCFString *)address];

			if (chat == nil) {
				IMAccountController *sharedAccountController = [%c(IMAccountController) sharedInstance];
				IMAccount *myAccount = [sharedAccountController mostLoggedInAccount];
				
				__NSCFString *handleId = (__NSCFString *)address;
				IMHandle *handle = [[%c(IMHandle) alloc] initWithAccount:myAccount ID:handleId alreadyCanonical:YES];
				
				chat = [registry chatForIMHandle:handle];
			}

			NSMutableArray* attachmentFileGuids = [NSMutableArray array];
			NSMutableArray* attachmentFiles = [NSMutableArray array];

			if ([attachments count] > 0)  {
				CKMediaObjectManager* si = [%c(CKMediaObjectManager) sharedInstance];
				IMFileTransferCenter* transferCenter = [%c(IMFileTransferCenter) sharedInstance];

				for (NSString* obj in attachments) {
					NSURL* fileURL = [NSURL fileURLWithPath:obj];
					CKMediaObject* object = [si mediaObjectWithFileURL:fileURL filename:nil transcoderUserInfo:@{} attributionInfo:@{} hideAttachment:NO];
					IMFileTransfer* transfer = [transferCenter transferForGUID:[object transferGUID] includeRemoved:YES];

					[transferCenter _addTransfer:transfer];

					[attachmentFileGuids addObject:[object transferGUID]];	
					[attachmentFiles addObject:transfer];
				}
			}

			BOOL filesReady = NO;
			
			while (!filesReady && [attachmentFiles count] > 0) {
				filesReady = YES;
				for (IMFileTransfer* obj in attachmentFiles) {
					if (!obj.isFinished) filesReady = NO;
				}
				[NSThread sleepForTimeInterval:0.2f];
			}

			IMMessage *message;

			if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 14.0) {
				if ([attachmentFileGuids count] > 0)
					message = [%c(IMMessage) instantMessageWithText:text messageSubject:(subject.length > 0 ? sub : nil) fileTransferGUIDs:[attachmentFileGuids copy] flags:1048581 threadIdentifier:nil];
				else
					message = [%c(IMMessage) instantMessageWithText:text flags:1048581 threadIdentifier:nil];
			} else {
				if ([attachmentFileGuids count] > 0)
					message = [%c(IMMessage) instantMessageWithText:text messageSubject:(subject.length > 0 ? sub : nil) fileTransferGUIDs:[attachmentFileGuids copy] flags:1048581];
				else
					message = [%c(IMMessage) instantMessageWithText:text flags:1048581];
			}

			[chat sendMessage:message];
			*/

			CKConversationList* list = [%c(CKConversationList) sharedConversationList];
			CKConversation* conversation = [list conversationForExistingChatWithGroupID:address];

			if (conversation != nil) {
				CKComposition* composition  = [[%c(CKComposition) alloc] initWithText:text subject:([subject length] > 0 ? subject : nil)];
				CKMediaObjectManager* si = [%c(CKMediaObjectManager) sharedInstance];

				for (NSString* obj in attachments) {

					NSURL* file_url = [NSURL fileURLWithPath:obj];
					CKMediaObject* object = [si mediaObjectWithFileURL:file_url filename:nil transcoderUserInfo:@{} attributionInfo:@{} hideAttachment:NO];

					composition = [composition compositionByAppendingMediaObject:object];
				}

				id message = [conversation messageWithComposition:composition];
				[conversation sendMessage:message newComposition:YES];

			} else {

				IMAccountController *sharedAccountController = [%c(IMAccountController) sharedInstance];
				IMAccount *myAccount = [sharedAccountController mostLoggedInAccount];
				
				__NSCFString *handleId = (__NSCFString *)address;
				IMHandle *handle = [[%c(IMHandle) alloc] initWithAccount:myAccount ID:handleId alreadyCanonical:YES];
				
				IMChatRegistry *registry = [%c(IMChatRegistry) sharedInstance];
				IMChat *chat = [registry chatForIMHandle:handle];

				IMMessage* immessage;
				if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 14.0)
					immessage = [%c(IMMessage) instantMessageWithText:text flags:1048581 threadIdentifier:nil];
				else
					immessage = [%c(IMMessage) instantMessageWithText:text flags:1048581];

				[chat sendMessage:immessage];
			}
		} else {
			NSLog(@"LibSMServer_app: Failed to connect to daemon");
		}
	});

}

- (void)setAllAsRead:(NSString *)chat {
	IMDaemonController* controller = [%c(IMDaemonController) sharedController];

	if ([controller connectToDaemon]) {
		IMChat* imchat = [[%c(IMChatRegistry) sharedInstance] existingChatWithChatIdentifier:(__NSCFString *)chat];
		[imchat markAllMessagesAsRead];
	} else {
		NSLog(@"LibSMServer_app: Couldn't connect to daemon to set %@ as read", chat);
	}	
}

/*- (void)sendReaction:(NSDictionary *)vals {
    NSString *address = vals[@"chat"];
    NSString *guid = vals[@"guid"];
    long long int reaction = [vals[@"reaction"] longLongValue];

    IMChat *chat = [[%c(IMChatRegistry) sharedInstance] existingChatWithChatIdentifier:address];

    __block IMMessage *item = nil;
    [[%c(IMChatHistoryController) sharedInstance] loadMessageWithGUID:guid completionBlock: ^(id msg){
		item = msg;
    }];

    while (item == nil) {};

    IMTextMessagePartChatItem *pci = [[%c(IMTextMessagePartChatItem) alloc] _initWithItem:item._imMessageItem text:item.text index:0 messagePartRange:item.associatedMessageRange subject:item.messageSubject];

    /// Beware: `item` is not the correct type for the following function. I don't know what the correct type is.
    [chat sendMessageAcknowledgment:reaction forChatItem:pci withMessageSummaryInfo:nil]; 

    NSLog(@"LibSMServer_app: Sent reaction");
}*/

- (NSArray *)getPinnedChats {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 14.0)
    	return [NSArray array];

	IMPinnedConversationsController* pinnedController = [%c(IMPinnedConversationsController) sharedInstance];
	NSOrderedSet* set = [pinnedController pinnedConversationIdentifierSet];

	return [set array];
}

- (void)launchSMS {
	dispatch_async(dispatch_get_main_queue(), ^{
	    [[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.apple.MobileSMS" suspended:YES];
	});
}

- (NSString *)checkIfRunning:(NSString *)bundle_id { /// Would return a _Bool but you can only send `id`s through MRYIPC funcs 
	SBApplication *app = [[%c(SBApplicationController) sharedInstance] applicationWithBundleIdentifier:bundle_id];
	return app.processState != nil ? @"YES" : @"NO";
}

@end

%hook SMSApplication

/// Credits to u/abhichaudhari for letting me know about this method
- (void)_messageReceived:(id)arg1 {

	%orig;
    
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

		MRYIPCCenter *sbCenter = [MRYIPCCenter centerNamed:@"com.ianwelker.smserver"];
		_Bool isRunning = [[sbCenter callExternalMethod:@selector(checkIfRunning:) withArguments:@"com.ianwelker.smserver"] isEqualToString:@"YES"];

		if (isRunning) {
		    IMChat *chat = (IMChat *)[(NSConcreteNotification *)arg1 object];
		    NSString *chat_id = MSHookIvar<NSString *>(chat, "_identifier");
		    NSMutableString *to_send_chat = [NSMutableString stringWithString:@"any"];

		    if (chat_id != nil)
			    to_send_chat = [NSMutableString stringWithString:chat_id];
		    else
			    NSLog(@"LibSMServer_app: received chat_id was nil, chat was %@", [chat description]);

		    MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
		    [center callExternalVoidMethod:@selector(handleReceivedTextWithCallback:) withArguments:to_send_chat];
		}
	});
}

%end

%hook IMTypingChatItem 

- (id)_initWithItem:(id)arg1 {
	/// This is called when another party starts typing :)
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

		MRYIPCCenter *sbCenter = [MRYIPCCenter centerNamed:@"com.ianwelker.smserver"];
		_Bool isRunning = [[sbCenter callExternalMethod:@selector(checkIfRunning:) withArguments:@"com.ianwelker.smserver"] isEqualToString:@"YES"];

		if (isRunning) {
			NSString* chat = [(IMMessageItem *)arg1 sender];

		    MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
		    [center callExternalVoidMethod:@selector(handlePartyTypingWithCallback:) withArguments:chat];
		}
	});

	return %orig;
}

%end

%hook IMDaemonController

/// This allows any process to communicate with imagent
- (unsigned)_capabilities {
	NSString *process = [[NSProcessInfo processInfo] processName];
	if ([process isEqualToString:@"SpringBoard"] || [process isEqualToString:@"MobileSMS"])
		return 17159;
	else
		return %orig;
}

- (unsigned) _gMyFZListenerCapabilities {
	NSString *process = [[NSProcessInfo processInfo] processName];
	if ([process isEqualToString:@"SpringBoard"] || [process isEqualToString:@"MobileSMS"])
		return 17159;
	else
		return %orig;
}

%end

/*
Sending acknowledgments --
    To send:
	Love: 2000
	Thumbs up: 2001
	Thumbs down: 2002
	Haha: 2003
	Exclamation: 2004
	Question: 2005
    To remove:
	Love: 3000
	Thumbs up: 3001
	Thumbs down: 3002
	etc
    To send uses sendMessageAcknowledgement:(long long)arg1 forChatItem:(IMTextMessagePartChatItem *(?))arg2 withMessageSummaryInfo:(idk? always shows `<decode: missing data>`)arg3 withGuid:(idk? shows same as wMSI)arg4;

    You can get an IMItem with [[%c(IMChatHistoryController) sharedInstance] loadMessageWithGUID:...], use that somehow to pass into the other function
*/

%ctor {
	
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

	if ([bundleID isEqualToString:@"com.apple.springboard"]) {
		SMServerIPC* smsCenter = [SMServerIPC sharedInstance];
	}
}
