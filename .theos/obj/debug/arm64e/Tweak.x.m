#line 1 "Tweak.x"
#import <MRYIPCCenter.h>

@interface CKConversationList
- (id)conversationForExistingChatWithGroupID:(id)arg1;
+ (id)sharedConversationList;
@end

@interface CKConversation
- (id)messageWithComposition:(id)arg1;
- (void)sendMessage:(id)arg1 newComposition:(bool)arg2;
@end

@interface CKComposition
- (id)initWithText:(id)arg1 subject:(id)arg2;
@end

@interface CKMessage
@end

@interface UIApplication (Undocumented)
- (_Bool)launchApplicationWithIdentifier:(id)arg1 suspended:(_Bool)arg2;
+ (id)sharedApplication;
@end


#include <substrate.h>
#if defined(__clang__)
#if __has_feature(objc_arc)
#define _LOGOS_SELF_TYPE_NORMAL __unsafe_unretained
#define _LOGOS_SELF_TYPE_INIT __attribute__((ns_consumed))
#define _LOGOS_SELF_CONST const
#define _LOGOS_RETURN_RETAINED __attribute__((ns_returns_retained))
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif

@class CKComposition; @class SMSApplication; @class CKConversationList; @class Springboard; 
static _Bool (*_logos_orig$_ungrouped$SMSApplication$application$didFinishLaunchingWithOptions$)(_LOGOS_SELF_TYPE_NORMAL SMSApplication* _LOGOS_SELF_CONST, SEL, id, id); static _Bool _logos_method$_ungrouped$SMSApplication$application$didFinishLaunchingWithOptions$(_LOGOS_SELF_TYPE_NORMAL SMSApplication* _LOGOS_SELF_CONST, SEL, id, id); 
static __inline__ __attribute__((always_inline)) __attribute__((unused)) Class _logos_static_class_lookup$CKComposition(void) { static Class _klass; if(!_klass) { _klass = objc_getClass("CKComposition"); } return _klass; }static __inline__ __attribute__((always_inline)) __attribute__((unused)) Class _logos_static_class_lookup$CKConversationList(void) { static Class _klass; if(!_klass) { _klass = objc_getClass("CKConversationList"); } return _klass; }
#line 25 "Tweak.x"


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
		[_center addTarget:self action:@selector(handleText:)];
	}
	return self;
}

- (void)handleText:(NSDictionary *)vals {

	NSString* body = vals[@"body"];
	NSString* address = vals[@"address"];

	CKConversationList* list = [_logos_static_class_lookup$CKConversationList() sharedConversationList];

	CKConversation* conversation = [list conversationForExistingChatWithGroupID:address];

	NSAttributedString* text = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", body]];
	CKComposition* composition = [[_logos_static_class_lookup$CKComposition() alloc] initWithText:text subject:nil];

	CKMessage* message = [conversation messageWithComposition:composition];
	[conversation sendMessage:message newComposition:YES];
}

@end

static _Bool _logos_method$_ungrouped$SMSApplication$application$didFinishLaunchingWithOptions$(_LOGOS_SELF_TYPE_NORMAL SMSApplication* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, id arg1, id arg2) {
	
	SMServerIPC* center = [SMServerIPC sharedInstance];

	NSLog(@"NLGf: Launched application");

	return _logos_orig$_ungrouped$SMSApplication$application$didFinishLaunchingWithOptions$(self, _cmd, arg1, arg2);
}





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
	}
	return self;
}

- (void) launchSMS {
	[[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.apple.MobileSMS" suspended:YES];
}

@end



static __attribute__((constructor)) void _logosLocalCtor_60a54890(int __unused argc, char __unused **argv, char __unused **envp) {

	
	LaunchSMSIPC* center = [LaunchSMSIPC sharedInstance];

	NSLog(@"NLGF: called ctor");
}
static __attribute__((constructor)) void _logosLocalInit() {
{Class _logos_class$_ungrouped$SMSApplication = objc_getClass("SMSApplication"); { MSHookMessageEx(_logos_class$_ungrouped$SMSApplication, @selector(application:didFinishLaunchingWithOptions:), (IMP)&_logos_method$_ungrouped$SMSApplication$application$didFinishLaunchingWithOptions$, (IMP*)&_logos_orig$_ungrouped$SMSApplication$application$didFinishLaunchingWithOptions$);}} }
#line 129 "Tweak.x"
