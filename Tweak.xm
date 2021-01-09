#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
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
		[_center addTarget:self action:@selector(delete:)];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedText:) name:@"__kIMChatMessageReceivedNotification" object:nil];
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sentText:) name:@"__kIMChatRegistryMessageSentNotification" object:nil];
	}
	return self;
}

- (void)receivedText:(NSConcreteNotification *)notif {
	_Bool isRunning = [[self checkIfRunning:@"com.ianwelker.smserver"] boolValue];

	if (isRunning) {
		IMMessage *msg = [[notif userInfo] objectForKey:@"__kIMChatValueKey"];
		NSString* guid = [msg guid];

		MRYIPCCenter *center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
		[center callExternalVoidMethod:@selector(handleReceivedTextWithCallback:) withArguments:guid];
	}
}

- (NSNumber *)sendText:(NSDictionary *)vals {
	__block NSNumber* ret_bool = 0;

	/// You have to run this on main thread to do the `mediaObjectWithFileURL` bit
	dispatch_sync(dispatch_get_main_queue(), ^{
		IMDaemonController* controller = [%c(IMDaemonController) sharedController];

		if ([controller connectToDaemon]) {
			NSArray* attachments = vals[@"attachment"];
			NSString* body = vals[@"body"];
			NSString* address = vals[@"address"];
			NSString* sub = vals[@"subject"];
			NSString* ret_guid; /// Will be used to give SMServer the guid of the sent text

			/// These items have to be `NSAttributedString`s. Don't ask me why.
			NSAttributedString* text = [[NSAttributedString alloc] initWithString:body];
			NSAttributedString* subject = [[NSAttributedString alloc] initWithString:sub];

			CKConversationList* list = [%c(CKConversationList) sharedConversationList];
			CKConversation* conversation = [list conversationForExistingChatWithGroupID:address];

			/// If conversation == nil, we've never talked to them before, and have to make a new conversation.
			if (conversation != nil) {
				CKComposition* composition  = [[%c(CKComposition) alloc] initWithText:text subject:([subject length] > 0 ? subject : nil)];

				/// The `CKMediaObjectManager` is what can initialize `CKMediaObject`s to add to the composition.
				CKMediaObjectManager* si = [%c(CKMediaObjectManager) sharedInstance];

				/// Iterate through and add all the attachments (`CKMediaObject`s) to the composition
				for (NSString* obj in attachments) {

					NSURL* file_url = [NSURL fileURLWithPath:obj];
					CKMediaObject* object = [si mediaObjectWithFileURL:file_url filename:nil transcoderUserInfo:@{} attributionInfo:@{} hideAttachment:NO];

					composition = [composition compositionByAppendingMediaObject:object];
				}

				/// It takes an `IMMessage` as the parameter.
				IMMessage* message = [conversation messageWithComposition:composition];
				[conversation sendMessage:message newComposition:YES];

				/// grab the guid to send back to SMServer
				ret_guid = [message guid];

			} else {
				/// If we get here, we don't have a conversation with them yet, so we have to
				/// use IMCore to create a conversation and send them a text through that.

				/// Here, we get our own account, which is used to initialize their handle.
				IMAccountController *sharedAccountController = [%c(IMAccountController) sharedInstance];
				IMAccount *myAccount = [sharedAccountController activeIMessageAccount];

				if (myAccount == nil)
					myAccount = [sharedAccountController activeSMSAccount];

				/// Here, we initilize their handle, using their address && our own account.
				__NSCFString *handleId = (__NSCFString *)address;
				IMHandle *handle = [[%c(IMHandle) alloc] initWithAccount:myAccount ID:handleId alreadyCanonical:YES];

				/// Their handle is then registered with the `IMChatRegistry` automatically, and we grab the 
				/// `IMChat` that was created for it, since we can send messages to that.
				IMChatRegistry *registry = [%c(IMChatRegistry) sharedInstance];
				IMChat *chat = [registry chatForIMHandle:handle];

				/// iOS 14+ and iOS 13- have different methods for initializing `IMMessage`s,
				/// so we have to check what we're working with.
				IMMessage* message;
				if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 14.0)
					message = [%c(IMMessage) instantMessageWithText:text flags:1048581 threadIdentifier:nil];
				else
					message = [%c(IMMessage) instantMessageWithText:text flags:1048581];

				[chat sendMessage:message];

				/// grab the guid to send back to SMServer
				ret_guid = [message guid];
			}

			/// Send the guid back to SMServer so that it can send the text info through the websocket.
			MRYIPCCenter *center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
			[center callExternalVoidMethod:@selector(handleReceivedTextWithCallback:) withArguments:ret_guid];

			ret_bool = @1;
		} else {
			NSLog(@"LibSMServer_app: Failed to connect to daemon");
		}
	});

	return ret_bool;
}

- (NSNumber *)setAllAsRead:(NSString *)chat {
	IMDaemonController* controller = [%c(IMDaemonController) sharedController];

	if ([controller connectToDaemon]) {
		IMChat* imchat = [[%c(IMChatRegistry) sharedInstance] existingChatWithChatIdentifier:(__NSCFString *)chat];
		[imchat markAllMessagesAsRead];

		return @1;
	} else {
		NSLog(@"LibSMServer_app: Couldn't connect to daemon to set %@ as read", chat);
	}

	return @0;
}

- (NSNumber *)sendTapback:(NSDictionary *)vals {
	IMDaemonController* controller = [%c(IMDaemonController) sharedController];

	if ([controller connectToDaemon]) {
		NSString *address = vals[@"chat"];
		NSString *guid = vals[@"guid"];
		long long int tapback = [vals[@"tapback"] longLongValue];

		/// Get the chat that the tapback will be sent in
		IMChat *chat = [[%c(IMChatRegistry) sharedInstance] existingChatWithChatIdentifier:address];

		/// I'm initializing the item to `nil` so that it is still nil
		/// if it is not able to get the item in the following block
		IMMessageItem *item = nil;

		// Sometimes it takes a few tries to actually load the messages correctly
		for (int t = 0; t < 2 && item == nil; t++) { 
			/// Have to call this to populate the `[chat chatItems]` array
			/// If you don't call this, then `[chat messageItemForGUID:]` returns nil no matter what
			[chat loadMessagesUpToGUID:guid date:nil limit:nil loadImmediately:YES];

			for (int i = 0; item == nil && i < 100; i++) /// Sometimes it takes a few tries here as well
				/// Get the item that has the guid we want
				item = [chat messageItemForGUID:guid];
		}

		if (item == nil)
			return @0; /// Sometimes necessary :(

		/// The `sendMessageAcknowledgment` method takes an IMTextMessagePartChatItem as the parameter,
		/// so we have to initilize one with these exact values.
		IMTextMessagePartChatItem *pci = [[%c(IMTextMessagePartChatItem) alloc] _initWithItem:item text:[item body] index:0 messagePartRange:NSMakeRange(0, [[item body] length]) subject:[item subject]];

		/// This `info` dictionary isn't perfectly accurate (sometimes `amc` has to be something different,
		/// and sometimes there's an `amb` value), but so far I haven't run into any issues.
		NSDictionary *info = @{@"amc": @1, @"ams": [[item body] string]};

		if ([[[UIDevice currentDevice] systemVersion] floatValue] < 14.0) 
			/// I honestly have no idea if this will work. No way to test
			[chat sendMessageAcknowledgment:tapback forChatItem:pci withMessageSummaryInfo:info];
		else
			[chat sendMessageAcknowledgment:tapback forChatItem:pci withAssociatedMessageInfo:info];

		/// Send tapback info back to SMServer so that it can send it through the websocket.
		MRYIPCCenter *center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
		[center callExternalVoidMethod:@selector(handleSentTapbackWithCallback:) withArguments:vals];

		return @1;
	} else {
		NSLog(@"LibSMServer_app: failed to connect to daemon to send tapback");
	}

	return @0;
}

- (NSArray *)getPinnedChats {
	if ([[[UIDevice currentDevice] systemVersion] floatValue] < 14.0)
		return [NSArray array];

	IMPinnedConversationsController* pinnedController = [%c(IMPinnedConversationsController) sharedInstance];
	NSOrderedSet* set = [pinnedController pinnedConversationIdentifierSet];

	return [set array];
}

- (NSNumber *)checkIfRunning:(NSString *)bundle_id { /// Would return a _Bool but you can only send `id`s through MRYIPC funcs 
	/// Just checks if a certain app with the bundle id `bundle_id` is running at all, background or foreground.
	SBApplication *app = [[%c(SBApplicationController) sharedInstance] applicationWithBundleIdentifier:bundle_id];
	return app.processState != nil ? @1 : @0;
}

- (NSNumber *)delete:(NSDictionary *)vals {
	IMDaemonController* controller = [%c(IMDaemonController) sharedController];

	/// Have to connect to the daemon to use many o the methods included in this block
	if ([controller connectToDaemon]) {
		NSString *chat_id = [vals objectForKey:@"chat"];
		NSString *text = [vals objectForKey:@"text"];
		IMChat* imchat = [[%c(IMChatRegistry) sharedInstance] existingChatWithChatIdentifier:(__NSCFString *)chat_id];

		/// If you couldn't get the chat that we need to affect, return failure.
		if (imchat == nil) return @0;

		if (text == nil || [text length] == 0) {
			/// deletes the conversation
			[imchat remove];

			return @1;
		} else {
			/// see the `sendTapback` function for specifics about the next few lines; they're used there too.
			IMMessageItem* item = nil;

			for (int i = 0; i < 2 && item == nil; i++) {
				[imchat loadMessagesUpToGUID:text date:nil limit:nil loadImmediately:YES];
				
				for (int l = 0; l < 100; l++)
					item = [imchat messageItemForGUID:text];
			}

			if (item == nil)
				return @0; /// sometimes necessary :(

			IMTextMessagePartChatItem *pci = [[%c(IMTextMessagePartChatItem) alloc] _initWithItem:item text:[item body] index:0 messagePartRange:NSMakeRange(0, [[item body] length]) subject:[item subject]];

			/// It takes an array so that you can delete multiple at a time
			[imchat deleteChatItems:@[pci]];

			return @1;
		}
	} else {
		NSLog(@"LibSMServer_app: Couldn't connect to daemon to delete");
	}

	return @0;
}

@end

%hook IMMessageItem

- (bool)isCancelTypingMessage {
	bool orig = %orig;

	/// if `orig` is true here, someone stopped typing.
	if (orig) {

		/// we have to grab this NSString* outside the dispatch_async block 'cause `self` gets deallocated pretty quickly.
		/// if we try to call anything on `self`, it crashes SpringBoard
		__block NSString* sender = [self sender];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

			MRYIPCCenter* sbCenter = [MRYIPCCenter centerNamed:@"com.ianwelker.smserver"];
			_Bool isRunning = [[sbCenter callExternalMethod:@selector(checkIfRunning:) withArguments:@"com.ianwelker.smserver"] boolValue];

			/// if SMServer is not running, trying to grab the MRYIPCCenter in it and call anything on it crashes SpringBoard, so we need to check.
			if (isRunning) {
				MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
				if (sender != nil)
					[center callExternalVoidMethod:@selector(handlePartyTypingWithCallback:) withArguments:@{@"chat": sender, @"typing": @0}];
			}
		});
	}

	return orig;
}

- (bool)isIncomingTypingMessage {
	bool orig = %orig;

	/// if `orig` is true here, somebody started typing.
	if (orig) {
		
		__block NSString* sender = [self sender];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

			MRYIPCCenter *sbCenter = [MRYIPCCenter centerNamed:@"com.ianwelker.smserver"];
			_Bool isRunning = [[sbCenter callExternalMethod:@selector(checkIfRunning:) withArguments:@"com.ianwelker.smserver"] boolValue];

			if (isRunning) {
				MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
				[center callExternalVoidMethod:@selector(handlePartyTypingWithCallback:) withArguments:@{@"chat": sender, @"typing": @1}];
			}
		});
	}
	return orig;
}

%end

%hook IMDaemonController

/// This allows SpringBoard, MobileSMS, and SMServer full access to communicate with imagent
- (unsigned)_capabilities {
	NSString *process = [[NSProcessInfo processInfo] processName];
	if ([process isEqualToString:@"SpringBoard"] || [process isEqualToString:@"MobileSMS"] || [process isEqualToString:@"SMServer"])
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
