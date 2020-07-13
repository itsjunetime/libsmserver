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
		[_center addTarget:self action:@selector(sendAttachment:)];
	}
	return self;
}

- (void)sendAttachment:(NSDictionary *)vals {

	NSArray* attachments = vals[@"attachment"];
	NSString* body = vals[@"body"];
	NSString* address = vals[@"address"];

	CKConversationList* list = [%c(CKConversationList) sharedConversationList];

	CKConversation* conversation = [list conversationForExistingChatWithGroupID:address];

	NSAttributedString* text = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", body]];
	CKComposition* composition = [[%c(CKComposition) alloc] initWithText:text subject:nil];

	CKMediaObjectManager* si = [%c(CKMediaObjectManager) sharedInstance];

	for (NSString* obj in attachments) {
		NSString *new_string = [NSString stringWithFormat:@"file://%@", obj];
		NSURL *file_url = [NSURL URLWithString:new_string];
		CKMediaObject* obj = [si mediaObjectWithFileURL:file_url filename:nil transcoderUserInfo:nil attributionInfo:@{} hideAttachment:NO];
		composition = [composition compositionByAppendingMediaObject:obj];
	}

	CKMessage* message = [conversation messageWithComposition:composition];
	[conversation sendMessage:message newComposition:YES];
}

@end

- (_Bool)application:(id)arg1 didFinishLaunchingWithOptions:(id)arg2 {
	
	SMServerIPC* center = [SMServerIPC sharedInstance];

	NSLog(@"NLGF: Launched application");

	return %orig;
}

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
	NSLog(@"NLGF: called LaunchSMS");

	[[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.apple.MobileSMS" suspended:YES];
}

- (void) relaunchSMServer {
	NSLog(@"NLGF: called relaunchSMServer");

	[[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.ianwelker.smserver" suspended:YES];
}

@end

%end

%ctor {
	
	LaunchSMSIPC* center = [LaunchSMSIPC sharedInstance];

	NSLog(@"NLGF: called ctor");
}