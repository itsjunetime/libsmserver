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
		[_center addTarget:self action:@selector(checkIfRunning:)];
		[_center addTarget:self action:@selector(sendTapback:)];
		//[_center addTarget:self action:@selector(delete:)];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedText:) name:@"__kIMChatMessageReceivedNotification" object:nil];
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sentText:) name:@"__kIMChatRegistryMessageSentNotification" object:nil];
	}
	return self;
}

- (void)receivedText:(NSConcreteNotification *)notif {
	_Bool isRunning = [[self checkIfRunning:@"com.ianwelker.smserver"] isEqualToString:@"YES"];

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

- (void)sendTapback:(NSDictionary *)vals {
	IMDaemonController* controller = [%c(IMDaemonController) sharedController];

	if ([controller connectToDaemon]) {
		NSString *address = vals[@"chat"];
		NSString *guid = vals[@"guid"];
		long long int tapback = [vals[@"tapback"] longLongValue];

		IMChat *chat = [[%c(IMChatRegistry) sharedInstance] existingChatWithChatIdentifier:address];
		IMMessageItem *item = nil;

		for (int t = 0; t < 2 && item == nil; t++) { // Sometimes it takes a few tries to actually load the messages correctly
			/// I'm just gonna hope that nobody tries to send a tapback for a text 1001+ back, I don't want to try to support that yet.
			[chat loadMessagesUpToGUID:nil date:nil limit:1000 loadImmediately:YES];

			for (int i = 0; item == nil && i < 100; i++) /// Sometimes it takes a few tries here as well
				item = [chat messageItemForGUID:guid];
		}

		if (item == nil)
			return; /// Sometimes necessary :(

		IMTextMessagePartChatItem *pci = [[%c(IMTextMessagePartChatItem) alloc] _initWithItem:item text:[item body] index:0 messagePartRange:NSMakeRange(0, [[item body] length]) subject:[item subject]];

		if ([[[UIDevice currentDevice] systemVersion] floatValue] < 14.0) /// I honestly have no idea if this will work. No way to test
			[chat sendMessageAcknowledgment:tapback forChatItem:pci withMessageSummaryInfo:nil];
		else
			[chat sendMessageAcknowledgment:tapback forChatItem:pci withAssociatedMessageInfo:@{@"amc": @1, @"ams": [[item body] string]}];

		MRYIPCCenter *center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
		[center callExternalVoidMethod:@selector(handleSentTapbackWithCallback:) withArguments:vals]; /// works to just send it back

	} else {
		NSLog(@"LibSMServer_app: failed to connect to daemon to send tapback");
	}
}

- (NSArray *)getPinnedChats {
	if ([[[UIDevice currentDevice] systemVersion] floatValue] < 14.0)
		return [NSArray array];

	IMPinnedConversationsController* pinnedController = [%c(IMPinnedConversationsController) sharedInstance];
	NSOrderedSet* set = [pinnedController pinnedConversationIdentifierSet];

	return [set array];
}

- (NSString *)checkIfRunning:(NSString *)bundle_id { /// Would return a _Bool but you can only send `id`s through MRYIPC funcs 
	SBApplication *app = [[%c(SBApplicationController) sharedInstance] applicationWithBundleIdentifier:bundle_id];
	return app.processState != nil ? @"YES" : @"NO";
}

/*- (void)delete:(NSDictionary *)vals {
	NSString *identifier = [vals objectForKey:@"id"];
	BOOL is_chat = [[vals objectForKey:@"is_chat"] isEqualToString:@"true"];
	IMChat* imchat = [[%c(IMChatRegistry) sharedInstance] existingChatWithChatIdentifier:(__NSCFString *)identifier];

	if (imchat == nil) return;

	if (is_chat) {
		[imchat remove];
	} else {
		NSLog(@"LibSMServer_app: No :)");
	}
}*/

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

%ctor {
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

	if ([bundleID isEqualToString:@"com.apple.springboard"])
		SMServerIPC* smsCenter = [SMServerIPC sharedInstance];
}
