#import <MRYIPCCenter.h>
#import "substrate.h"
#import "Tweak.h"

@interface SMServerIPC : NSObject
@end

@implementation SMServerIPC {
	MRYIPCCenter* _center;
}

+(instancetype)sharedInstance {
	static dispatch_once_t onceToken = 0;
	__strong static SMServerIPC* sharedInstance = nil;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
	});
	return sharedInstance;
}

-(instancetype)init {
	if ((self = [super init])) {
		_center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserver"];
		[_center addTarget:self action:@selector(sendText:)];
		[_center addTarget:self action:@selector(setAllAsRead:)];
		//[_center addTarget:self action:@selector(setTyping:inConversation:)];

		/*UIDevice *device = [UIDevice currentDevice];
		[device setBatteryMonitoringEnabled:YES];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendBatteryNotification:) name:UIDeviceBatteryLevelDidChangeNotification object:device];*/
	}
	return self;
}

- (void)sendText:(NSDictionary *)vals {

	NSArray* attachments = vals[@"attachment"];
	NSString* body = vals[@"body"];
	NSString* address = vals[@"address"];

	NSAttributedString* text = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", body]];
	
	CKConversationList* list = [%c(CKConversationList) sharedConversationList];
	CKConversation* conversation = [list conversationForExistingChatWithGroupID:address];
	
	if (conversation != nil) { /// If they've texted this person before
		CKComposition* composition = [[%c(CKComposition) alloc] initWithText:text subject:nil];
		CKMediaObjectManager* si = [%c(CKMediaObjectManager) sharedInstance];

		for (NSString* obj in attachments) {

			NSMutableString* new_string = [obj mutableCopy];

			if (![[obj substringToIndex:7] isEqualToString:@"file://"])
				new_string = [NSMutableString stringWithFormat:@"file://%@", obj];

			NSURL *file_url = [NSURL URLWithString:new_string];
			
			CKMediaObject* object = [si mediaObjectWithFileURL:file_url filename:nil transcoderUserInfo:nil attributionInfo:@{} hideAttachment:NO];
			composition = [composition compositionByAppendingMediaObject:object];
		}
		
		CKMessage* message = [conversation messageWithComposition:composition];

		[conversation sendMessage:message newComposition:YES];

	} else { /// If they haven't

		IMAccountController *sharedAccountController = [%c(IMAccountController) sharedInstance];
		IMAccount *myAccount = [sharedAccountController mostLoggedInAccount];
		
		__NSCFString *handleId = (__NSCFString *)address;
		IMHandle *handle = [[%c(IMHandle) alloc] initWithAccount:myAccount ID:handleId alreadyCanonical:YES];
		
		IMChatRegistry *registry = [%c(IMChatRegistry) sharedInstance];
		IMChat *chat = [registry chatForIMHandle:handle];

		/// Flags is always just 1048581 in a regular message, with/without images/videos.
		/// 19922949 with a instant recording
		IMMessage *immessage = [%c(IMMessage) instantMessageWithText:text flags:1048581];

		[chat sendMessage:immessage];
	}
}

/*- (void)setTyping:(NSDictionary *)vals { /// Will be used when I implement typing indicators
	_Bool is = [vals[@"isTyping"] isEqualToString:@"YES"]; /// Since you can't directly pass _Bools through NSDictionaries
	NSString *address = vals[@"address"];

	CKConversationList *sharedList = [%c(CKConversationList) sharedConversationList];
	CKConversation *convo =  [sharedList conversationForExistingChatWithGroupID:address];

	[convo setLocalUserIsTyping:is];
}*/

- (void)setAllAsRead:(NSString *)chat {
    IMChat *imchat = [[%c(IMChatRegistry) sharedInstance] existingChatWithChatIdentifier:chat];
    [imchat markAllMessagesAsRead];
}

/*- (void)sendBatteryNotification:(NSNotification *)notification {
	NSLog(@"LibSMServer_app: Got battery notification, sending IPC");

	MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
	[center callExternalVoidMethod:@selector(handleBatteryChanged) withArguments:nil];
}*/

@end

%hook SMSApplication

- (_Bool)application:(id)arg1 didFinishLaunchingWithOptions:(id)arg2 {
	_Bool orig = %orig;

	NSLog(@"LibSMServer_app: You launched SMSApplication! Woohoo!");

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		SMServerIPC* center = [SMServerIPC sharedInstance];
	});

	return orig;
}

/// Credits to u/abhichaudhari for letting me know about this method
- (void)_messageReceived:(id)arg1 {
    
	NSLog(@"LibSMServer_app: Received a message");

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

		MRYIPCCenter *sbCenter = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverLaunch"];
		_Bool isRunning = [[sbCenter callExternalMethod:@selector(checkIfRunning:) withArguments:@"com.ianwelker.smserver"] isEqualToString:@"YES"];

		if (isRunning) {
		    IMChat *chat = (IMChat *)[(NSConcreteNotification *)arg1 object];
		    NSString *chat_id = MSHookIvar<NSString *>(chat, "_identifier");
		    NSMutableString *to_send_chat = [NSMutableString stringWithString:@"any"];

		    if (chat_id != nil) {
			    to_send_chat = [NSMutableString stringWithString:chat_id];
		    } else {
			    NSLog(@"LibSMServer_app: received chat_id was nil, chat was %@", [chat description]);
		    }

		    MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
		    [center callExternalVoidMethod:@selector(handleReceivedTextWithCallback:) withArguments:to_send_chat];
		}
	});

	%orig;
}

%end

@interface LaunchSMSIPC : NSObject
@end

@implementation LaunchSMSIPC {
	MRYIPCCenter* _center;
}

+ (instancetype)sharedInstance {
	static dispatch_once_t onceToken = 0;
	__strong static LaunchSMSIPC* sharedInstance = nil;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
	});
	return sharedInstance;
}

- (instancetype)init {
	if ((self = [super init])) {
		_center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverLaunch"];
		[_center addTarget:self action:@selector(launchSMS)];
		[_center addTarget:self action:@selector(relaunchSMServer)];
		[_center addTarget:self action:@selector(checkIfRunning:)];
	}
	return self;
}

- (void)launchSMS {
	NSLog(@"LibSMServer_app: called LaunchSMS");

	dispatch_async(dispatch_get_main_queue(), ^{
	    [[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.apple.MobileSMS" suspended:YES];
	});
}

- (void)relaunchSMServer {
	NSLog(@"LibSMServer_app: called relaunchSMServer");

	dispatch_async(dispatch_get_main_queue(), ^{
	    [[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.ianwelker.smserver" suspended:YES];
	    [[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.apple.MobileSMS" suspended:YES];
	});
}

- (NSString *)checkIfRunning:(NSString *)bundle_id { /// Would return a _Bool but you can only send `id`s through MRYIPC funcs 
	SBApplication *app = [[%c(SBApplicationController) sharedInstance] applicationWithBundleIdentifier:bundle_id];
	return app.processState != nil ? @"YES" : @"NO";
}

@end

%ctor {
	
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

	if ([bundleID isEqualToString:@"com.apple.springboard"]) {
		NSLog(@"LibSMServer_app: Running in springboard, creating ipc center");
		LaunchSMSIPC* center = [LaunchSMSIPC sharedInstance];
	}
}
