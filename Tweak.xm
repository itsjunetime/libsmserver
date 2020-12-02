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
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedText:) name:@"__kIMChatMessageReceivedNotification" object:nil];
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sentText:) name:@"__kIMChatRegistryMessageSentNotification" object:nil];
	}
	return self;
}

- (void)receivedText:(NSConcreteNotification *)notif {
	MRYIPCCenter *sbCenter = [MRYIPCCenter centerNamed:@"com.ianwelker.smserver"];
	_Bool isRunning = [[sbCenter callExternalMethod:@selector(checkIfRunning:) withArguments:@"com.ianwelker.smserver"] isEqualToString:@"YES"];

	if (isRunning) {
		IMMessage *msg = [[notif userInfo] objectForKey:@"__kIMChatValueKey"];
		NSString* guid = [msg guid];

		MRYIPCCenter *center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
		[center callExternalVoidMethod:@selector(handleReceivedTextWithCallback:) withArguments:guid];
	}
}

- (void)sendText:(NSDictionary *)vals {
	__block NSString* ret_guid;

	/// You have to run this on main thread to do the `mediaObjectWithFileURL` bit
	dispatch_sync(dispatch_get_main_queue(), ^{
		IMDaemonController* controller = [%c(IMDaemonController) sharedController];

		if ([controller connectToDaemon]) {
			NSArray* attachments = vals[@"attachment"];
			NSString* body = vals[@"body"];
			NSString* address = vals[@"address"];
			NSString* sub = vals[@"subject"];

			NSAttributedString* text = [[NSAttributedString alloc] initWithString:body];
			NSAttributedString* subject = [[NSAttributedString alloc] initWithString:sub];

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

				ret_guid = [(IMMessage *)message guid];

			} else {
				IMAccountController *sharedAccountController = [%c(IMAccountController) sharedInstance];

				IMAccount *myAccount = [sharedAccountController activeIMessageAccount];
				if (myAccount == nil)
					myAccount = [sharedAccountController activeSMSAccount];

				__NSCFString *handleId = (__NSCFString *)address;
				IMHandle *handle = [[%c(IMHandle) alloc] initWithAccount:myAccount ID:handleId alreadyCanonical:YES];

				IMChatRegistry *registry = [%c(IMChatRegistry) sharedInstance];
				IMChat *chat = [registry chatForIMHandle:handle];

				IMMessage* message;
				if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 14.0)
					message = [%c(IMMessage) instantMessageWithText:text flags:1048581 threadIdentifier:nil];
				else
					message = [%c(IMMessage) instantMessageWithText:text flags:1048581];

				[chat sendMessage:message];

				ret_guid = [(IMMessage *)message guid];
			}
		} else {
			NSLog(@"LibSMServer_app: Failed to connect to daemon");
		}
	});

	MRYIPCCenter *center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
	[center callExternalVoidMethod:@selector(handleReceivedTextWithCallback:) withArguments:ret_guid];
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
	IMDaemonController* controller = [%c(IMDaemonController) sharedController];

	if ([controller connectToDaemon]) {
		NSString *address = vals[@"chat"];
		NSString *guid = vals[@"guid"];
		long long int reaction = [vals[@"reaction"] longLongValue];

		IMChat *chat = [[%c(IMChatRegistry) sharedInstance] existingChatWithChatIdentifier:address];
		NSLog(@"LibSMServer_app: Got chat: %@", chat);

		id item = [chat _itemForGUID:guid];
		NSLog(@"LibSMServer_app: got item: %@, other: %@, next: %@ three: %@", item, other_item, next_item, item_three);

		/// Beware: `item` is not the correct type for the following function. I don't know what the correct type is.
		//[chat sendMessageAcknowledgment:reaction forChatItem:pci withMessageSummaryInfo:nil];

		NSLog(@"LibSMServer_app: Sent reaction");
	} else {
		NSLog(@"LibSMServer_app: failed to connect");
	}
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

	You can get an IMItem with [[%c(IMChatHistoryController) sharedInstance] loadMessageWithGUID:...], use that somehow to pass into the other function?
*/

%ctor {
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

	if ([bundleID isEqualToString:@"com.apple.springboard"]) {
		SMServerIPC* smsCenter = [SMServerIPC sharedInstance];
	}
}
