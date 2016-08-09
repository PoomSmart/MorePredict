#import "Header.h"

CFStringRef PreferencesNotification = CFSTR("com.PS.MorePredict.prefs");
CFStringRef maxPadKey = CFSTR("UIPredictionExpandedPad");
CFStringRef landscapeKey = CFSTR("UIPredictionCountForLandscape");
CFStringRef portraitKey = CFSTR("UIPredictionCountForPortrait");
CFStringRef gapKey = CFSTR("UIPredictionGap");
CFStringRef barHeightFactorKey = CFSTR("UIPredictionBarHeightFactor");
NSString *path = @"/var/mobile/Library/Preferences/com.PS.MorePredict.plist";

BOOL maxPad;
NSUInteger landscapeCount;
NSUInteger portraitCount;
NSUInteger maxCount;
CGFloat predictionGap;
CGFloat barHeightFactor;

void updateMaxCount()
{
	maxCount = portraitCount;
	if (landscapeCount > maxCount)
		maxCount = landscapeCount;
}

CGFloat appropriateCellHeight(CGFloat original)
{
	CGFloat height = original;
    if (IS_IPAD)
		height = isiOS9Up ? [NSClassFromString(@"UIKeyboardAssistantBar") assistantBarHeight] * 41 / 55 : original; // Huh?
	else {
		NSInteger orientation = [[UIKeyboard activeKeyboard] interfaceOrientation];
    	if (orientation == 0)
			orientation = [UIApplication.sharedApplication _frontMostAppOrientation];
		height = [NSClassFromString(@"UIKeyboardPredictionView") predictionViewHeightForState:1 orientation:orientation];
	}
	return height;
}

extern "C" void setCellRect(UIKeyboardPredictionCell *cell, CGRect frame, NSUInteger index, NSUInteger count)
{
	BOOL isLast = (index == count - 1);
	BOOL notHeadOrTail = index == 0 || isLast;
	CGFloat gap = [%c(UIKeyboardPredictionView) overlapHeight];
	CGFloat cellWidth = (frame.size.width - (count - 1) * gap) / count;
	CGFloat cellHeight = appropriateCellHeight(frame.size.height);
	CGFloat cellX = index == 0 ? 0 : (index * (cellWidth + gap));
	CGFloat cellY = frame.size.height / 2 - cellHeight / 2;
	CGRect cellFrame = CGRectMake(cellX, cellY, cellWidth, cellHeight);
	CGFloat activeWidth = cellWidth + (notHeadOrTail ? (2 * gap) : gap);
	CGRect activeFrame = CGRectMake(cellX, cellY, activeWidth, cellHeight);
	CGFloat baseWidth = cellWidth + (notHeadOrTail ? 0.0 : gap);
	CGRect baseFrame = CGRectMake(cellX, cellY, baseWidth, cellHeight);
	cell.activeFrame = activeFrame;
	cell.collapsedFrame = baseFrame;
	cell.baseFrame = baseFrame;
	cell.frame = cellFrame;
}

extern "C" void reloadPredictionBar()
{
	UIKeyboardPredictionView *kbView = (UIKeyboardPredictionView *)[objc_getClass("UIKeyboardPredictionView") activeInstance];
	if ([kbView isKindOfClass:objc_getClass("UIKeyboardPredictionView")]) {
		if (!kbView.show)
			return;
		NSMutableArray *cells = MSHookIvar<NSMutableArray *>(kbView, "m_predictionCells");
		if (cells.count == 0)
			return;
		for (UIKeyboardPredictionCell *cell in cells)
			[cell removeFromSuperview];
		[cells release];
		NSUInteger cellCount = [objc_getClass("UIKeyboardPredictionView") numberOfCandidates];
		cells = [[NSMutableArray alloc] initWithCapacity:cellCount];
		if (cellCount > 0) {
			NSUInteger index = 0;
			do {
				UIKeyboardPredictionCell *cell = [[objc_getClass("UIKeyboardPredictionCell") alloc] initWithFrame:CGRectZero];
				cell.label.font = [UIFont systemFontOfSize:18.0];
				cell.opaque = NO;
				[kbView addSubview:cell];
				setCellRect(cell, kbView.frame, index, cellCount);
				[cells addObject:cell];
				index++;
			} while (index < cellCount);
		}
		MSHookIvar<NSMutableArray *>(kbView, "m_predictionCells") = cells;
		[UIKeyboardImpl.activeInstance.autocorrectionController updateSuggestionViews];
	}
}

BOOL is_kbd;

static NSUInteger predictionCountForLandscape(BOOL landscape)
{
	return landscape ? landscapeCount : portraitCount;
}

static NSUInteger predictionCount()
{
	UIInterfaceOrientation orientation = [[UIScreen mainScreen] _interfaceOrientation];
	BOOL isLandscape = orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight;
	return predictionCountForLandscape(isLandscape);
}

%group app

%hook UICompatibilityInputViewController

- (void)didRotateFromInterfaceOrientation:(NSInteger)orientation
{
	%orig;
	if (landscapeCount != portraitCount)
		reloadPredictionBar();
}

%end

%hook UITextReplacementGeneratorForCorrections

- (void)setMaxCountAfterAutocorrectionGuesses:(NSUInteger)count
{
	%orig(predictionCount());
}

- (NSUInteger)maxCountAfterAutocorrectionGuesses
{
	return predictionCount();
}

- (void)setMaxCountAfterSpellingGuesses:(NSUInteger)count
{
	%orig(predictionCount());
}

%end

BOOL padHook = NO;

%hook UIDevice

- (UIUserInterfaceIdiom)userInterfaceIdiom
{
	return padHook ? UIUserInterfaceIdiomPhone : %orig;
}

%end

%hook UIKeyboardPredictionView

+ (CGFloat)overlapHeight
{
	return predictionGap;
}

+ (CGFloat)predictionViewHeightForState:(NSInteger)state orientation:(NSInteger)orientation
{
	CGFloat height = %orig;
	return height > 0.0 ? height * barHeightFactor : height;
}

// iOS 9.0+
+ (CGFloat)predictionViewWidthForOrientation:(NSInteger)orientation
{
	padHook = maxPad;
	CGFloat width = %orig;
	padHook = NO;
	return width;
}

+ (NSUInteger)numberOfCandidates
{
	return predictionCount();
}

- (id)initWithFrame:(CGRect)frame
{
	padHook = !isiOS9Up;
	self = %orig;
	padHook = NO;
	return self;
}

- (NSUInteger)messageCount
{
	return predictionCount();
}

- (NSUInteger)maxMessageCount
{
	return predictionCount();
}

- (void)_setPredictions:(NSArray *)predictions autocorrection:(TIAutocorrectionList *)autocorrection
{
	%orig;
	[self setCellsFrame:self.frame];
}

%new
- (void)setCellsFrame:(CGRect)frame
{
	if (MSHookIvar<BOOL>(self, "m_isMinimized"))
		return;
	NSMutableArray *cells = MSHookIvar<NSMutableArray *>(self, "m_predictionCells");
	if (cells) {
		NSInteger state = self.state;
		if (state != 0) {
			NSUInteger cellCount = cells.count;
			if (cellCount > 0) {
				NSUInteger index = 0;
				do {
					UIKeyboardPredictionCell *cell = cells[index];
					setCellRect(cell, frame, index, cellCount);
					index++;
				} while (index < cellCount);
			}
		}
	}
}

- (void)setFrame:(CGRect)frame
{
	padHook = !isiOS9Up;
	%orig;
	padHook = NO;
	[self setCellsFrame:frame];
}

%end

%end

%group kbd

BOOL fakeCount = NO;
BOOL markCode1 = NO;
BOOL markCode2 = YES;
int seeArrays = 0;
NSUInteger excess = 0;

%hook __NSPlaceholderArray

- (id)initWithCapacity:(NSUInteger)capacity
{
	if (fakeCount && markCode1) {
		if (capacity == 2 || capacity == 3) {
			capacity = maxCount;
			seeArrays++;
		}
		if (seeArrays == 2)
			markCode1 = NO;
	}
	return %orig(capacity);
}

%end

%hook __NSArrayM

- (NSUInteger)count
{
	NSUInteger count = %orig;
	if (fakeCount && markCode2) {
		if (count > 2 && excess++ <= maxCount - 3)
			return 2;
		excess = 0;
	}
	return count;
}

%end

%hook TIKeyboardInputManagerZephyr

- (id)autocorrection
{
	if (fakeCount)
		markCode1 = YES;
	return %orig;
}

- (id)completionCandidates
{
	if (fakeCount)
		markCode2 = NO;
	id r = %orig;
	if (fakeCount)
		markCode2 = YES;
	return r;
}

- (id)extendedAutocorrection:(id)arg1 spanningInputsForCandidates:(id)arg2
{
	markCode2 = NO;
	return %orig;
}

- (TIAutocorrectionList *)autocorrectionList
{
	fakeCount = YES;
	TIAutocorrectionList *t1 = %orig;
	fakeCount = markCode1 = markCode2 = NO;
	return t1;
}

- (id)autocorrectionListForEmptyInputWithDesiredCandidateCount:(NSUInteger)count
{
	return %orig(maxCount);
}

%end

%hook TICandidateCommitHistory

- (id)initWithMaxCommittedCandidateCount:(NSUInteger)count
{
	return %orig(maxCount);
}

- (NSUInteger)maxCommittedCandidateCount
{
	return maxCount;
}

- (void)setMaxCommittedCandidateCount:(NSUInteger)count
{
	%orig(maxCount);
}

%end

%hook TIKeyboardInputManager

- (NSUInteger)maxCandidateCount
{
	return maxCount;
}

- (void)setMaxCandidateCount:(NSUInteger)count
{
	%orig(maxCount);
}

%end

%end

static void letsprefs()
{
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:path];
	id object0 = prefs[(NSString *)maxPadKey];
	id object1 = prefs[(NSString *)landscapeKey];
	id object2 = prefs[(NSString *)portraitKey];
	id object3 = prefs[(NSString *)gapKey];
	id object4 = prefs[(NSString *)barHeightFactorKey];
	maxPad = [object0 boolValue];
	landscapeCount = object1 ? [object1 intValue] : 3;
	portraitCount = object2 ? [object2 intValue] : 3;
	predictionGap = object3 ? [object3 doubleValue] : 1.0;
	barHeightFactor = object4 ? [object4 doubleValue] : 1.0;
}

static void prefsChanged()
{
	letsprefs();
	if (!is_kbd)
		reloadPredictionBar();
	updateMaxCount();
}

%ctor
{
	NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
	NSUInteger count = args.count;
	if (count != 0) {
		NSString *executablePath = args[0];
		if (executablePath) {
			BOOL isApplication = [executablePath rangeOfString:@"/Application"].location != NSNotFound;
			BOOL isSpringBoard = [[executablePath lastPathComponent] isEqualToString:@"SpringBoard"];
			BOOL isExtension = [executablePath rangeOfString:@"appex"].location != NSNotFound;
			if (isExtension)
				return;
			is_kbd = [[executablePath lastPathComponent] isEqualToString:@"kbd"];
			if (is_kbd || isApplication || isSpringBoard) {
				CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)prefsChanged, PreferencesNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
				letsprefs();
			}
			if (is_kbd) {
				%init(kbd);
			}
			if (isApplication || isSpringBoard) {
				%init(app);
			}
		}
	}
}