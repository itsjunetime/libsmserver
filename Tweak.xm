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
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemsChanged:) name:@"__kIMChatItemsDidChangeNotification" object:nil];
	}
	return self;
}

- (void)receivedText:(NSConcreteNotification *)notif {
	BOOL isRunning = [[self checkIfRunning:@"SMServer"] boolValue];

	if (isRunning) {
		IMMessage *msg = [[notif userInfo] objectForKey:@"__kIMChatValueKey"];
		NSString* guid = [msg guid];

		MRYIPCCenter *center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
		[center callExternalVoidMethod:@selector(handleReceivedTextWithCallback:) withArguments:guid];
	}
}

- (void)itemsChanged:(NSConcreteNotification *)notif {
	BOOL isRunning = [[self checkIfRunning:@"SMServer"] boolValue];
	IMMessage* message = [(IMChat*)[notif object] lastSentMessage];

	if (isRunning) {
		if (([message isRead] || [message isDelivered]) && [message isFromMe]) {
			NSString* guid = [message guid];

			MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
			if (![message isRead]) {
				[center callExternalVoidMethod:@selector(handleReceivedTextWithCallback:) withArguments:guid];
			} else {
				[center callExternalVoidMethod:@selector(handleTextReadWithCallback:) withArguments:guid];
			}
		}
	}
}

- (NSNumber *)sendText:(NSDictionary *)vals {
	__block NSNumber* ret_bool = 0;

	/// You have to run this on main thread to do the `mediaObjectWithFileURL` bit
	IMDaemonController* controller = [%c(IMDaemonController) sharedController];

	void (^processBlock)() = ^{
		if ([controller connectToDaemon]) {
			NSArray* attachments = vals[@"attachment"];
			NSString* body = vals[@"body"];
			NSString* address = vals[@"address"];
			NSString* sub = vals[@"subject"];

			/// These items have to be `NSAttributedString`s. Don't ask me why.
			NSAttributedString* text = [[NSAttributedString alloc] initWithString:body];
			NSAttributedString* subject = [[NSAttributedString alloc] initWithString:sub];

			CKConversationList* list = [%c(CKConversationList) sharedConversationList];
			CKConversation* conversation = [list conversationForExistingChatWithGroupID:address];

			/// If conversation == nil, we've never talked to them before, and have to make a new conversation.
			if (conversation != nil) {
				CKComposition* composition = [%c(CKComposition) composition];

				/// The `CKMediaObjectManager` is what can initialize `CKMediaObject`s to add to the composition.
				CKMediaObjectManager* si = [%c(CKMediaObjectManager) sharedInstance];

				/// Iterate through and add all the attachments (`CKMediaObject`s) to the composition
				for (NSString* obj in attachments) {

					NSURL* file_url = [NSURL fileURLWithPath:obj];
					CKMediaObject* object = [si mediaObjectWithFileURL:file_url filename:nil transcoderUserInfo:@{} attributionInfo:@{} hideAttachment:NO];

					composition = [composition compositionByAppendingMediaObject:object];
				}

				// We have to set text after setting images so that the text is set with the correct NSAttributedString
				if ([text length] > 0)
					composition = [composition compositionByAppendingText:text];

				if (subject != nil  && [subject length] > 0)
					[composition setSubject:subject];

				/// It takes an `IMMessage` as the parameter.
				IMMessage* message = [conversation messageWithComposition:composition];
				[conversation sendMessage:message newComposition:YES];

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
				if ([[[%c(UIDevice) currentDevice] systemVersion] floatValue] >= 14.0)
					message = [%c(IMMessage) instantMessageWithText:text flags:1048581 threadIdentifier:nil];
				else
					message = [%c(IMMessage) instantMessageWithText:text flags:1048581];

				[chat sendMessage:message];
			}

			ret_bool = @1;
		} else {
			NSLog(@"LibSMServer_app: Failed to connect to daemon");
		}
	};

	if ([NSThread isMainThread])
		processBlock();
	else
		dispatch_sync(dispatch_get_main_queue(), ^{
			processBlock();
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

		IMTextMessagePartChatItem* pci = [self getIMTMPCIForStructuredGUID:guid inChat:address];

		/// This `info` dictionary isn't perfectly accurate (sometimes `amc` has to be something different,
		/// and sometimes there's an `amb` value), but so far I haven't run into any issues.
		NSDictionary *info = @{@"amc": @1, @"ams": [[(IMMessageItem *)[pci _item] body] string]};

		if ([[[%c(UIDevice) currentDevice] systemVersion] floatValue] < 14.0)
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
	if ([[[%c(UIDevice) currentDevice] systemVersion] floatValue] < 14.0)
		return [NSArray array];

	IMDaemonController* controller = [%c(IMDaemonController) sharedController];

	if ([controller connectToDaemon]) {
		IMPinnedConversationsController* pinnedController = [%c(IMPinnedConversationsController) sharedInstance];
		NSArray* pins = [[pinnedController pinnedConversationIdentifierSet] array];

		CKConversationList* list = [%c(CKConversationList) sharedConversationList];
		NSMutableArray* convos = [NSMutableArray arrayWithCapacity:[pins count]];

		/// ugh. So `pins` contains an array of pinning identifiers, not chat identifiers. So we have to iterate through
		/// and get the chat identifiers that correspond with the pinning identifiers, since SMServer parses them by chat identifier.
		for (id obj in pins) {
			CKConversation* convo = (CKConversation *)[list conversationForExistingChatWithPinningIdentifier:obj];
			if (convo == nil) continue;
			NSString* identifier = [[convo chat] chatIdentifier];
			[convos addObject:identifier];
		}

		return convos;
	}

	NSLog(@"LibSMServer_app: Could not connect to daemon to get pinned chats");
	return [NSArray array];
}

- (NSNumber *)checkIfRunning:(NSString *)bundle_id { /// Would return a _Bool but you can only send `id`s through MRYIPC funcs
	/// Just checks if a certain app with the bundle id `bundle_id` is running at all, background or foreground.
	NSTask* task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/sh"];
	[task setArguments:@[@"-c", [NSString stringWithFormat:@"ps aux | grep %@ | grep -v grep", bundle_id]]];

	NSPipe* pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	NSFileHandle* file = [pipe fileHandleForReading];

	[task launch];

	NSData* data = [file readDataToEndOfFile];
	NSString* out = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	return out.length > 0 ? @1 : @0;
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
			IMTextMessagePartChatItem* pci = [self getIMTMPCIForStructuredGUID:text inChat:chat_id];

			/// It takes an array so that you can delete multiple at a time
			[imchat deleteChatItems:@[pci]];

			return @1;
		}
	} else {
		NSLog(@"LibSMServer_app: Couldn't connect to daemon to delete");
	}

	return @0;
}

- (IMTextMessagePartChatItem *)getIMTMPCIForStructuredGUID:(NSString *)guid inChat:(NSString *)chat {
	IMDaemonController* controller = [%c(IMDaemonController) sharedController];

	if ([controller connectToDaemon]) {
		// full_guid is just the text's guid, minus the part identifier (e.g. `p:o/`, `bp:`, etc)
		NSString *full_guid = [guid substringFromIndex:[guid length] - 36];
		IMChat* imchat = [[%c(IMChatRegistry) sharedInstance] existingChatWithChatIdentifier:chat];

		if (imchat == nil)
			return nil;

		// index specifies which part of the message it will be sent to, like if there are 4 attachments and text
		// this specifies which attachment (or the text) to send it to
		long long index = 0;

		// set the index based on the part identifier. This section is incomplete right now.
		if ([[guid substringToIndex:2] isEqualToString:@"p:"]) {
			index = (long long)[[guid substringWithRange:NSMakeRange(2, 1)] intValue];
		}

		/// I'm initializing the message to `nil` so that it is still nil
		/// if it is not able to get the item in the following block
		IMMessage* msg = nil;

		// Sometimes it takes a few tries to actually load the messages correctly
		for (int i = 0; i < 2 && msg == nil; i++) {
			/// Have to call this to populate the `[chat chatItems]` array
			/// If you don't call this, then `[chat messageForGUID:]` returns nil no matter what
			[imchat loadMessagesUpToGUID:full_guid date:nil limit:nil loadImmediately:YES];

			for (int l = 0; l < 100 && msg == nil; l++) // sometimes it takes a few tries here as well
				/// Get the message that has the guid we want
				msg = [imchat messageForGUID:full_guid];
		}

		if (msg == nil || [msg _imMessageItem] == nil)
			return nil;

		IMMessageItem *item = [msg _imMessageItem];

		// the `messagePartRange` relates to the same information as the index, but reverse.
		// When the index == $number_attachments, the range is $number_attachments ... $number_attachments+$body_length
		// Else, it is $index ... $index+1
		int range_start = index;
		int range_end = [[item body] length];
		int num_atts = [[msg inlineAttachmentAttributesArray] count];

		if (index != num_atts) {
			range_end = index + 1;
		} else if ([msg hasInlineAttachments]) {
			range_start = num_atts;
			range_end += num_atts;
		}

		/// The `sendMessageAcknowledgment` method takes an IMTextMessagePartChatItem as the parameter,
		/// so we have to initilize one with these exact values.
		IMTextMessagePartChatItem *pci = [[%c(IMTextMessagePartChatItem) alloc]
		                                                    _initWithItem:item
		                                                    text:[item body]
		                                                    index:index
		                                                    messagePartRange:NSMakeRange(range_start, range_end)
		                                                    subject:[item subject]];

		return pci;
	} else {
		NSLog(@"LibSMServer_app: Couldn't connect to daemon to get IMTextMessagePartChatItem");
	}

	return nil;
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
			_Bool isRunning = [[sbCenter callExternalMethod:@selector(checkIfRunning:) withArguments:@"SMServer"] boolValue];
			NSLog(@"LibSMServer_app: in async, isRunning: %d", isRunning);

			/// if SMServer is not running, trying to grab the MRYIPCCenter in it and call anything on it crashes SpringBoard, so we need to check.
			if (isRunning) {
				MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
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
			_Bool isRunning = [[sbCenter callExternalMethod:@selector(checkIfRunning:) withArguments:@"SMServer"] boolValue];

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
		[SMServerIPC sharedInstance];
}
