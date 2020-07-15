#import <MRYIPCCenter.h>

@interface NSObject (Undocumented)
+ (id)description;
@end

@interface CKConversationList
- (id)conversationForExistingChatWithGroupID:(id)arg1;
+ (id)sharedConversationList;
@end

@interface CKConversation
- (id)messageWithComposition:(id)arg1;
- (void)sendMessage:(id)arg1 newComposition:(bool)arg2;
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
- (_Bool)launchApplicationWithIdentifier:(id)arg1 suspended:(_Bool)arg2;
+ (id)sharedApplication;
@end

%hook SMSApplication

/*@interface IPCTextWatcher
- (void)handleReceivedTextWithCallback;
@end*/

@interface SMServerIPC : NSObject
@end

@implementation SMServerIPC {
	MRYIPCCenter* _center;
}

+(void)load {
	[self sharedInstance];
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
	}
	return self;
}

- (void)sendText:(NSDictionary *)vals {

	NSArray* attachments = vals[@"attachment"];
	NSString* body = vals[@"body"];
	NSString* address = vals[@"address"];

	/// Get the shared list of all existing conversations
	CKConversationList* list = [%c(CKConversationList) sharedConversationList];

	/// Get the conversation for a specific person.
	/// Address should be phone like '+15293992094' or email, or group chat id like 'chat8373916825376185'
	CKConversation* conversation = [list conversationForExistingChatWithGroupID:address];

	/// Create string with the body of the text
	NSAttributedString* text = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", body]];

	/// Initialize composition with the body of the text, no subject for now. Subject could be another NSAttributedString.
	CKComposition* composition = [[%c(CKComposition) alloc] initWithText:text subject:nil];

	/// Get the CKMediaObjectManager sharedInstance for adding new objects.
	CKMediaObjectManager* si = [%c(CKMediaObjectManager) sharedInstance];

	for (NSString* obj in attachments) {
		/// Get the file path of the file, such as 'file:///private/var/mobile/Media/DCIM/100APPLE/IMG_000.JPG'
		NSString *new_string = [NSString stringWithFormat:@"file://%@", obj];

		/// Turn that string into a URL
		NSURL *file_url = [NSURL URLWithString:new_string];

		/// Create a CKMediaObject from the URL, everything else nil + NO for hidden
		CKMediaObject* obj = [si mediaObjectWithFileURL:file_url filename:nil transcoderUserInfo:nil attributionInfo:@{} hideAttachment:NO];
		
		/// Add the media Object onto the composition
		composition = [composition compositionByAppendingMediaObject:obj];
	}

	/// Turn the composition into a message
	CKMessage* message = [conversation messageWithComposition:composition];

	/// Send it!
	[conversation sendMessage:message newComposition:YES];
}

@end

- (_Bool)application:(id)arg1 didFinishLaunchingWithOptions:(id)arg2 {
	
	SMServerIPC* center = [SMServerIPC sharedInstance];

	NSLog(@"LibSMServer_app: Launched application");

	return %orig;
}

/*- (void)_messageReceived:(id)arg1 {
	/// This will hopefully call something in the app to update the variable for the latest texts, 
	/// but it's not working right now. Maybe some time in the future.
    
	NSLog(@"LibSMServer_app: Received a message");

    MRYIPCCenter* center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverHandleText"];
    [center callExternalMethod:@selector(handleReceivedTextWithCallback) withArguments:nil];

	NSLog(@"LibSMServer_app: Got past message received");

	%orig;
}*/

%end

%hook Springboard

@interface LaunchSMSIPC : NSObject
@end

@implementation LaunchSMSIPC {
	MRYIPCCenter* _center;
}

+(void)load {
	[self sharedInstance];
}

+(instancetype)sharedInstance {
	static dispatch_once_t onceToken = 0;
	__strong static LaunchSMSIPC* sharedInstance = nil;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
	});
	return sharedInstance;
}

-(instancetype)init {
	if ((self = [super init])) {
		_center = [MRYIPCCenter centerNamed:@"com.ianwelker.smserverLaunch"];
		[_center addTarget:self action:@selector(launchSMS)];
		[_center addTarget:self action:@selector(relaunchSMServer)];
	}
	return self;
}

- (void) launchSMS {
	NSLog(@"LibSMServer_app: called LaunchSMS");

	[[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.apple.MobileSMS" suspended:YES];
}

- (void) relaunchSMServer {
	NSLog(@"LibSMServer_app: called relaunchSMServer");

	[[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.ianwelker.smserver" suspended:YES];

	/// Also reopen mobileSMS 'cause it can be shut down if the server is running for too long
	[[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.apple.MobileSMS" suspended:YES];
}

@end

%end

%ctor {
	
	LaunchSMSIPC* center = [LaunchSMSIPC sharedInstance];

	NSLog(@"LibSMServer_app: called ctor");
}